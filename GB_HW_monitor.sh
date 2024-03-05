#!/bin/bash
Today=$(date +%Y%m%d)
LogDir=/var/log/system
LogFile=${LogDir}/${Today}_`hostname`.log
expire_days=7

Interval=10					# Monitoring Interval

Temp_major=94 				# CPU upper-non critical
Temp_critical=95			# CPU upper-critical

FAN_Default_CNT="4"			# FAN count
RPM_Lower="1500"			# FAN lower-non critical

Mem_Default_CNT="6"			# Memory count
DIMM_Slots=("DIMM_P0_A0"
            "DIMM_P0_B0"
            "DIMM_P0_D0"
            "DIMM_P1_F1"
            "DIMM_P1_G0"
            "DIMM_P1_H0")	# Actual DIMM Slots

CPU_Temp(){

	TIMESTAMP=`date "+%Y-%m-%d %H:%M:%S"`
	
	CPU_Temp=$(ipmitool sdr type temperature | grep CPU | awk '{print $1,$9}')
	CPU0_Temp=$(grep CPU0_TEMP <<< $CPU_Temp | awk '{print $2}')
	CPU1_Temp=$(grep CPU1_TEMP <<< $CPU_Temp | awk '{print $2}')

	# CPU0 Temperature check
	if [ ${CPU0_Temp} -ge ${Temp_critical} ]; then
		echo -e "${TIMESTAMP} [CRIT] CPU0 Temp		: ${CPU0_Temp} degree C is over ${Temp_critical}"	>> $LogFile
	elif [ ${CPU0_Temp} -ge ${Temp_major} ]; then
		echo -e "${TIMESTAMP} [MAJO] CPU0 Temp		: ${CPU0_Temp} degree C is over ${Temp_major}"		>> $LogFile
	else
		echo -e "${TIMESTAMP} [INFO] CPU0 Temp		: ${CPU0_Temp} degree C is normal"			>> $LogFile
	fi

	# CPU1 Temperature check
	if [ ${CPU1_Temp} -ge ${Temp_critical} ]; then
		echo -e "${TIMESTAMP} [CRIT] CPU1 Temp		: ${CPU1_Temp} degree C is over ${Temp_critical}"	>> $LogFile
	elif [ ${CPU1_Temp} -ge ${Temp_major} ]; then
		echo -e "${TIMESTAMP} [MAJO] CPU1 Temp		: ${CPU1_Temp} degree C is over ${Temp_major}"		>> $LogFile
	else
		echo -e "${TIMESTAMP} [INFO] CPU1 Temp		: ${CPU1_Temp} degree C is normal"			>> $LogFile
	fi

}

Mem_Info(){

	TIMESTAMP=`date "+%Y-%m-%d %H:%M:%S"`
	
	Mem_Info=$(dmidecode -t memory | grep -E 'Size: [0-9]' -A 3)
	Mem_Size=($(grep Size <<< $Mem_Info | awk '{print $2}'))
	Mem_Slots=($(grep Locator <<< $Mem_Info | awk '{print $2}'))

	# Memory count check
	for ((i=0 ; i<Mem_Default_CNT ; i++))
    do
        if [ ${Mem_Slots[i]} == ${DIMM_Slots[i]} ]; then
		    echo -e "${TIMESTAMP} [INFO] ${Mem_Slots[i]}		: ${Mem_Size[i]} GB"		>> $LogFile
		else
            echo -e "${TIMESTAMP} [ERRO] ${Mem_Slots[i]}		: ERROR"		>> $LogFile
        fi
	done
}

FAN_RPM(){
	
	TIMESTAMP=`date "+%Y-%m-%d %H:%M:%S"`
		
	FAN_RPM=$(ipmitool sdr type fan | grep RPM | awk '{print $1,$9}')
	FAN_CNT=$(echo -e "${FAN_RPM}" | wc -l)
	RPM_list=$(echo -e "${FAN_RPM}" | awk '{print $2}')
	
	SYS_RPM=$(grep BPB_FAN_1A <<< ${FAN_RPM} | awk '{print $2}')
	GPU_RPM=$(grep BPB_FAN_4A <<< ${FAN_RPM} | awk '{print $2}')

	#SYS_RPM=$(grep SYS_RPM1 <<< ${FAN_RPM} | awk '{print $2}')
	#GPU_RPM=$(grep GPU12_FAN <<< ${FAN_RPM} | awk '{print $2}')

	# FAN count check
	if [ ${FAN_CNT} -ne ${FAN_Default_CNT} ]; then
		echo -e "${TIMESTAMP} [CRIT] One of FAN is failure"						>> $LogFile
	else
		for RPM in ${RPM_list}
		do
			if [ ${RPM} -le ${RPM_Lower} ]; then
				echo -e "${TIMESTAMP} [CRIT] FAN RPM		: ${RPM} RPM is LOW"	>> $LogFile	
				return 0
			fi
		done
		
		echo -e "${TIMESTAMP} [INFO] System FAN RPM	: ${SYS_RPM} RPM is normal"			>> $LogFile
		echo -e "${TIMESTAMP} [INFO] GPU FAN RPM		: ${GPU_RPM} RPM is normal"		>> $LogFile
	fi
	
}

PSU(){
	
	TIMESTAMP=`date "+%Y-%m-%d %H:%M:%S"`
	last_event=$(ipmitool sel list | grep "Power Supply" | tail -1)
	last_status=$(awk '{print $16}' <<< ${last_event})
	last_num=$(awk '{print $1}' <<< ${last_event})

	if [ "$last_status" == "Asserted" ]; then
		echo -e "${TIMESTAMP} [CRIT] $(awk '{print $11,$12,$13,$14,$16}' <<< ${last_event})"	>> $LogFile
	else
		echo -e "${TIMESTAMP} [INFO] Power Supply		: Normal"				>> $LogFile
	fi
}

RAID(){

	TIMESTAMP=`date "+%Y-%m-%d %H:%M:%S"`

	vd_list=$(/opt/MegaRAID/storcli/storcli64 /c0 show nolog | grep -A 8 "VD LIST")
	os_raid=$(grep "0/0" <<< ${vd_list} | awk '{print $3}')
	data_raid=$(grep "1/1" <<< ${vd_list} | awk '{print $3}')

	pd_list=$(/opt/MegaRAID/storcli/storcli64 /c0 show nolog | grep -A 10 "PD LIST")

	if [ ${os_raid} == "Optl" ]; then
		echo -e "${TIMESTAMP} [INFO] OS RAID		: Optimal"		>> $LogFile
	else 
		echo -e "${TIMESTAMP} [CRIT] OS RAID 		: NOT Optimal"		>> $LogFile
		echo -e "=================== RAID Status INFO ==========================="		>> $LogFile
		echo -e "${vd_list}"							>> $LogFile
		echo -e "${pd_list}"							>> $LogFile
	fi

	if [ ${data_raid} == "Optl" ]; then
		echo -e "${TIMESTAMP} [INFO] DATA RAID 		: Optimal"		>> $LogFile
	else 
		echo -e "${TIMESTAMP} [CRIT] DATA RAID 		: NOT Optimal"		>> $LogFile
		echo -e "=================== RAID Status INFO ==========================="		>> $LogFile
		echo -e "${vd_list}"							>> $LogFile
		echo -e "${pd_list}"							>> $LogFile
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

	PSU
	sleep $Interval

	RAID
	sleep $Interval

	if [ "$Today" != $(date +%Y%m%d) ]; then
		Today=$(date +%Y%m%d)
		LogFile=${LogDir}/${Today}_`hostname`.log
		find ${LogDir}/* -type f -mtime +${expire_days} -exec rm -f {} \;
	fi

done

