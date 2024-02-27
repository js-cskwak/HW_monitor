#!/bin/bash
Today=$(date +%Y%m%d)
LogDir=/var/log/ipmi
LogFile=${LogDir}/${Today}_`hostname`.log
expire_days=7

Interval=10

CPU_Temp(){

	TIMESTAMP=`date "+%Y-%m-%d %H:%M:%S"`
	Temp_major=94
	Temp_critical=95

	CPU_Temp=$(ipmitool sdr type temperature | grep CPU | awk '{print $1,$9}')
	CPU0_Temp=$(grep CPU0_TEMP <<< $CPU_Temp | awk '{print $2}')
	CPU1_Temp=$(grep CPU1_TEMP <<< $CPU_Temp | awk '{print $2}')

	# CPU0 Temperature check
	if [ ${CPU0_Temp} -ge ${Temp_critical} ]; then
		echo -e "${TIMESTAMP} [Critical] CPU0 Temp	: ${CPU0_Temp} degree C is over ${Temp_critical}"	>> $LogFile
	elif [ ${CPU0_Temp} -ge ${Temp_major} ]; then
		echo -e "${TIMESTAMP} [Major] CPU0 Temp		: ${CPU0_Temp} degree C is over ${Temp_major}"		>> $LogFile
	else
		echo -e "${TIMESTAMP} [Info] CPU0 Temp		: ${CPU0_Temp} degree C is normal"			>> $LogFile
	fi

	# CPU1 Temperature check
	if [ ${CPU1_Temp} -ge ${Temp_critical} ]; then
		echo -e "${TIMESTAMP} [Critical] CPU1 Temp	: ${CPU1_Temp} degree C is over ${Temp_critical}"	>> $LogFile
	elif [ ${CPU1_Temp} -ge ${Temp_major} ]; then
		echo -e "${TIMESTAMP} [Major] CPU1 Temp		: ${CPU1_Temp} degree C is over ${Temp_major}"		>> $LogFile
	else
		echo -e "${TIMESTAMP} [Info] CPU1 Temp		: ${CPU1_Temp} degree C is normal"			>> $LogFile
	fi

}

FAN_RPM(){
	
	TIMESTAMP=`date "+%Y-%m-%d %H:%M:%S"`
	DEFAULT_CNT="4"
	RPM_Lower="1500"
	
	FAN_RPM=$(ipmitool sdr type fan | grep RPM | awk '{print $1,$9}')
	FAN_CNT=$(echo -e "${FAN_RPM}" | wc -l)
	RPM_list=$(echo -e "${FAN_RPM}" | awk '{print $2}')
	
	SYS_RPM=$(grep BPB_FAN_1A <<< ${FAN_RPM} | awk '{print $2}')
	GPU_RPM=$(grep BPB_FAN_4A <<< ${FAN_RPM} | awk '{print $2}')

	#SYS_RPM=$(grep SYS_RPM1 <<< ${FAN_RPM} | awk '{print $2}')
	#GPU_RPM=$(grep GPU12_FAN <<< ${FAN_RPM} | awk '{print $2}')

	# FAN count check
	if [ ${FAN_CNT} -ne ${DEFAULT_CNT} ]; then
		echo -e "${TIMESTAMP} [Critical] One of FAN is failure"						>> $LogFile
	else
		for RPM in ${RPM_list}
		do
			if [ ${RPM} -le ${RPM_Lower} ]; then
				echo -e "${TIMESTAMP} [Critical] FAN RPM		: ${RPM} RPM is LOW"	>> $LogFile	
				return 0
			fi
		done
		
		echo -e "${TIMESTAMP} [Info] System FAN RPM	: ${SYS_RPM} RPM is normal"			>> $LogFile
		echo -e "${TIMESTAMP} [Info] GPU FAN RPM		: ${GPU_RPM} RPM is normal"		>> $LogFile
	fi
	
}

PSU(){
	
	TIMESTAMP=`date "+%Y-%m-%d %H:%M:%S"`
	last_event=$(ipmitool sel list | grep "Power Supply" | tail -1)
	last_status=$(awk '{print $16}' <<< ${last_event})
	last_num=$(awk '{print $1}' <<< ${last_event})

	if [ "$last_status" == "Asserted" ]; then
		echo -e "${TIMESTAMP} [Critical] $(awk '{print $11,$12,$13,$14,$16}' <<< ${last_event})"	>> $LogFile
	else
		echo -e "${TIMESTAMP} [Info] Power Supply		: Normal"				>> $LogFile
	fi
}

RAID(){

	TIMESTAMP=`date "+%Y-%m-%d %H:%M:%S"`

	vd_list=$(/opt/MegaRAID/storcli/storcli64 /c0 show nolog | grep -A 8 "VD LIST")
	os_raid=$(grep "0/0" <<< ${vd_list} | awk '{print $3}')
	data_raid=$(grep "1/1" <<< ${vd_list} | awk '{print $3}')

	pd_list=$(/opt/MegaRAID/storcli/storcli64 /c0 show nolog | grep -A 10 "PD LIST")

	if [ ${os_raid} == "Optl" ]; then
		echo -e "${TIMESTAMP} [Info] OS RAID		: Optimal"		>> $LogFile
	else 
		echo -e "${TIMESTAMP} [Critical] OS RAID 	: NOT Optimal"		>> $LogFile
		echo -e "=================== RAID Status INFO ==========================="		>> $LogFile
		echo -e "${vd_list}"							>> $LogFile
		echo -e "${pd_list}"							>> $LogFile
	fi

	if [ ${data_raid} == "Optl" ]; then
		echo -e "${TIMESTAMP} [Info] DATA RAID 		: Optimal"		>> $LogFile
	else 
		echo -e "${TIMESTAMP} [Critical] DATA RAID 	: NOT Optimal"		>> $LogFile
		echo -e "=================== RAID Status INFO ==========================="		>> $LogFile
		echo -e "${vd_list}"							>> $LogFile
		echo -e "${pd_list}"							>> $LogFile
	fi

}

while true
do

	CPU_Temp
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
