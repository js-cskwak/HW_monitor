# HW_monitor
Gigabyte 제품 기준으로 작성 됨.
- CPU 온도
- Memory 장착 상태
- FAN RPM 
- GPU 상태
- PSU 상태
- RAID 상태 검출

로그 디렉토리는 /var/log/system 디렉토리에 로그 쌓임. (system 디렉토리 생성)

GB_HW_monitor.service 파일은 /etc/systemd/system/ 디렉토리 밑에 copy 할것. 
(아래와 같인 systemctl 운영 가능 하도록 설정 함)

- 프로그램 시작
[root@SVC system]# systemctl start GB_HW_monitor.service

- 프로그램 종료
[root@SVC system]# systemctl stop GB_HW_monitor.service


