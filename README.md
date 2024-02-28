# HW_monitor
Gigabyte G293-S41 기준으로 작성 됨.
- CPU 온도
- FAN RPM
- PSU 상태
- RAID 상태 검출

로그 디렉토리는 /var/log/ipmi 디렉토리에 로그 쌓임. (ipmi 디렉토리 생성 할 것)

GB_HW_monitor.service 파일은 /etc/systemd/system/ 디렉토리 밑에 copy 할것. 
(아래와 같인 systemctl 운영 가능 하도록 설정 함)

프로그램 시작
[root@SVC system]# systemctl start GB_HW_monitor.service
[root@SVC system]# 

프로그램 종료
[root@SVC system]# systemctl stop GB_HW_monitor.service
[root@SVC system]# 

