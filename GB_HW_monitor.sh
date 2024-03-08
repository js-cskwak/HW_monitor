#!/bin/bash
source /root/HW_monitor/config

declare -A levels=([INFO]=0 [WARN]=1 [ERRO]=2)

Today=$(date +%Y%m%d)
LogFile=${Log_Dir}/${Today}_`hostname`.log
DIMM_Slots=(${DIMM_Slots})
HDD_Bay_Slots=(${HDD_Bay_Slots})

WriteLog() {
	local log_message=$1
	local log_priority=$2
	TIMESTAMP=`date "+%Y-%m-%d %H:%M:%S"`

	#check if level exists
	[[ ${levels[$log_priority]} ]] || return 1

	#check if level is enough
	(( ${levels[$log_priority]} < ${levels[$Log_Level]} )) && return 2

	#log here
	echo -e "${TIMESTAMP} [${log_priority}] ${log_message}"			>> $LogFile
}

CPU_Temp(){

	CPU_Temp=$(ipmitool sdr type temperature | grep CPU | awk '{print $1,$9}')
	CPU0_Temp=$(grep CPU0_TEMP <<< $CPU_Temp | awk '{print $2}')
	CPU1_Temp=$(grep CPU1_TEMP <<< $CPU_Temp | awk '{print $2}')

	# CPU0 Temperature check
	if [ ${CPU0_Temp} -ge ${Temp_critical} ]; then
		WriteLog "CPU0 Temp	: ${CPU0_Temp} degree C UPPER-CRITICAL" "ERRO"
	elif [ ${CPU0_Temp} -ge ${Temp_major} ]; then
		WriteLog "CPU0 Temp	: ${CPU0_Temp} degree C UPPER-NON-CRITICAL" "WARN"
	else
		WriteLog "CPU0 Temp	: ${CPU0_Temp} degree C" "INFO"
	fi

	# CPU1 Temperature check
	if [ ${CPU1_Temp} -ge ${Temp_critical} ]; then
		WriteLog "CPU1 Temp	: ${CPU1_Temp} degree C UPPER-CRITICAL" "ERRO"
	elif [ ${CPU1_Temp} -ge ${Temp_major} ]; then
		WriteLog "CPU1 Temp	: ${CPU1_Temp} degree C UPPER-NON-CRITICAL" "WARN"
	else
		WriteLog "CPU1 Temp	: ${CPU1_Temp} degree C" "INFO"
	fi

}

Mem_Info(){

	Mem_Info=$(dmidecode -t memory | grep -E 'Size: [0-9]' -A 3)
	Mem_Size=($(grep Size <<< $Mem_Info | awk '{print $2}'))
	Mem_Slots=($(grep Locator <<< $Mem_Info | awk '{print $2}'))

	# Memory count check
	for ((i=0 ; i<Mem_Default_CNT ; i++))
	do
        if [ ${Mem_Slots[i]} == ${DIMM_Slots[i]} ]; then
			WriteLog "${Mem_Slots[i]}	: ${Mem_Size[i]} GB" "INFO"
		else
        	WriteLog "${Mem_Slots[i]}	: NOT INSTALLED" "ERRO"
        fi
	done
}

FAN_RPM(){
	
	FAN_RPM=$(ipmitool sdr type fan | grep RPM | awk '{print $1,$9}')
	FAN_CNT=$(echo -e "${FAN_RPM}" | wc -l)
	RPM_list=$(echo -e "${FAN_RPM}" | awk '{print $2}')
	
	SYS_RPM=$(grep ${SYS_FAN} <<< ${FAN_RPM} | awk '{print $2}')
	GPU_RPM=$(grep ${GPU_FAN} <<< ${FAN_RPM} | awk '{print $2}')

	# FAN count check
	if [ ${FAN_CNT} -ne ${FAN_Default_CNT} ]; then
		WriteLog "Some FAN IS NOT INSTALLED OR MISSING" "ERRO"
	else
		for RPM in ${RPM_list}
		do
			if [ ${RPM} -le ${RPM_Lower} ]; then
				WriteLog "FAN RPM	: ${RPM} RPM is LOW" "ERRO"
				return 0
			fi
		done
		WriteLog "SYS FAN RPM	: ${SYS_RPM} RPM" "INFO"
		WriteLog "GPU FAN RPM	: ${GPU_RPM} RPM" "INFO"
	fi
	
}

NIC_Info(){
	
	IP_Link=$(ip link | grep -E "en[a-z]|bond")
	NIC_Devs=($(grep "en[a-z]" <<< ${IP_Link} | cut -d ":" -f2))
	NIC_Status=($(grep "en[a-z]" <<< ${IP_Link} | awk -F ',' '{print $5}' | cut -d '>' -f1))
	Bond_Status=$(grep "bond0:" <<< ${IP_Link} | awk -F ',' '{print $5}' | cut -d '>' -f1)

	if [ ${Bond_Status} == 'LOWER_UP' ]; then
		WriteLog "Bondig bond0	: UP" "INFO"
	else
		WriteLog "Bondig bond0	: DOWN" "ERRO"
	fi	
	
	for ((i=0 ; i<${#NIC_Devs[@]} ; i++))
	do
		if [ ${NIC_Status[i]} == 'LOWER_UP' ]; then
			WriteLog "Eth ${NIC_Devs[i]}	: UP" "INFO"
		else
			WriteLog "Eth ${NIC_Devs[i]}	: DOWN" "ERRO"
		fi
	done
}

RAID(){

	RAID_Info=$(/opt/MegaRAID/storcli/storcli64 /c0 show nolog)
	VD_List=$(grep -A 8 "VD LIST" <<< ${RAID_Info})
	OS_RAID=$(grep ${OS_VD} <<< ${VD_List} | awk '{print $3}')
	Data_RAID=$(grep ${DATA_VD} <<< ${VD_List} | awk '{print $3}')

	PD_List=$(grep -A 10 "PD LIST" <<< ${RAID_Info})

	HDD_Bays=($(grep ":[0-9]" <<< ${PD_List} | awk '{print $1}' | awk -F ':' '{print $2}'))
	HDD_State=($(grep ":[0-9]" <<< ${PD_List} | awk '{print $3}'))

	if [ ${OS_RAID} == "Optl" ] && [ ${Data_RAID} == "Optl" ]; then
		WriteLog "RAID Status	: Optimal" "INFO"
		return 0
	fi

	if [ ${#HDD_Bays[@]} -eq ${#HDD_Bay_Slots[@]} ]; then
		for ((i=0 ; i<${#HDD_Bay_Slots[@]} ; i++))
		do
			if [ ${HDD_State[i]} == 'Onln' ]; then
				WriteLog "HDD Bay ${HDD_Bays[i]}	: ${HDD_State[i]}" "INFO"
			else
				WriteLog "HDD Bay ${HDD_Bays[i]}	: ${HDD_State[i]}" "ERRO"
			fi
		done
	else
		Missing_Bay=(`echo ${HDD_Bay_Slots[@]} ${HDD_Bays[@]} | tr ' ' '\n' | sort | uniq -u `)
		WriteLog "HDD Bay ${Missing_Bay}	: MISSING" "ERRO"
	fi
}

GPU_Info(){
	
	GPU_Info=$(nvidia-smi --format=csv --query-gpu=name,utilization.gpu,fan.speed,temperature.gpu)
	#grep NVIDIA <<< ${GPU_Info} | awk -F ',' '{print $1,$2,$3,$4}' | cut -d ' ' -f3,5,8,11
	#GPU_Info=$(cat /root/HW_monitor/GPU)
	GPU_Model=($(grep "NVIDIA" <<< ${GPU_Info} | awk -F ',' '{print $1,$2,$3,$4}' | cut -d ' ' -f3))
	GPU_Usage=($(grep "NVIDIA" <<< ${GPU_Info} | awk -F ',' '{print $1,$2,$3,$4}' | cut -d ' ' -f5))
	GPU_Fan=($(grep "NVIDIA" <<< ${GPU_Info} | awk -F ',' '{print $1,$2,$3,$4}' | cut -d ' ' -f8))
	GPU_Temp=($(grep "NVIDIA" <<< ${GPU_Info} | awk -F ',' '{print $1,$2,$3,$4}' | cut -d ' ' -f11))
		
	for ((i=0 ; i<${#GPU_Model[@]} ; i++))
	do
		if [ ${GPU_Usage[i]} -gt ${GPU_critical} ]; then
			WriteLog "GPU ${GPU_Model[i]} 	: GPU usage : ${GPU_Usage[i]}%, FAN Speed : ${GPU_Fan[i]}%, Temp : ${GPU_Temp[i]} C" "ERRO"	
		elif [ ${GPU_Usage[i]} -gt ${GPU_major} ]; then
			WriteLog "GPU ${GPU_Model[i]} 	: GPU usage : ${GPU_Usage[i]}%, FAN Speed : ${GPU_Fan[i]}%, Temp : ${GPU_Temp[i]} C" "WARN"	
		else
			WriteLog "GPU ${GPU_Model[i]} 	: GPU usage : ${GPU_Usage[i]}%, FAN Speed : ${GPU_Fan[i]}%, Temp : ${GPU_Temp[i]} C" "INFO"	
		fi

	done
}

PSU(){
	
	PSU_Event=$(ipmitool sel list | grep "Power Supply AC lost")
	PSU1_status=$(grep ${PSU1} <<< ${PSU_Event} | tail -1)
	PSU2_status=$(grep ${PSU2} <<< ${PSU_Event} | tail -1)
	#Last_Status=$(awk '{print $16}' <<< ${Last_Event})
	
	if [ "$PSU1_status" == "Asserted" ]; then
		WriteLog "PSU1		: Power Supply AC lost" "ERRO"
	else
		WriteLog "PSU1		: Normal" "INFO"
	fi

	if [ "$PSU2_status" == "Asserted" ]; then
		WriteLog "PSU2		: Power Supply AC lost" "ERRO"
	else
		WriteLog "PSU2		: Normal" "INFO"
	fi
}

while true
do

	CPU_Temp
	sleep $Interval

	Mem_Info
	sleep $Interval

	FAN_RPM
	sleep $Interval

	NIC_Info
	sleep $Interval

	RAID
	sleep $Interval

	GPU_Info
	sleep $Interval

	PSU
	sleep $Interval


	if [ "$Today" != $(date +%Y%m%d) ]; then
		Today=$(date +%Y%m%d)
		LogFile=${Log_Dir}/${Today}_`hostname`.log
		find ${Log_Dir}/* -type f -mtime +${Log_Days} -exec rm -f {} \;
	fi

done
