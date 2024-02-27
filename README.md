# HW_monitor
Gigabyte G293-S41 기준으로 작성 됨.
- CPU 온도
- FAN RPM
- PSU 상태
- RAID 상태 검출

로그 디렉토리는 /var/log/ipmi 디렉토리에 로그 쌓임. (ipmi 디렉토리 생성 할 것)

GB_HW_monitor.service 파일은 /etc/systemd/system/ 디렉토리 밑에 copy 할것. 
(아래와 같인 systemctl 운영 가능 하도록 설정 함)

[root@SVC system]# systemctl status GB_HW_monitor.service 
● GB_HW_monitor.service - GB_HW_Monitor
   Loaded: loaded (/etc/systemd/system/GB_HW_monitor.service; enabled; vendor preset: disabled)
   Active: active (running) since Tue 2024-02-27 17:57:42 KST; 4h 49min left
 Main PID: 1525 (GB_HW_monitor.s)
    Tasks: 2 (limit: 306119)
   Memory: 11.6M
   CGroup: /system.slice/GB_HW_monitor.service
           ├─ 1525 /bin/bash /root/GB_HW_monitor.sh
           └─24258 sleep 10

Feb 27 17:57:42 SVC systemd[1]: Started GB_HW_Monitor.
[root@SVC system]# 

