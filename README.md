# 컨테이너로 PXE 환경 작성 스크립트 사용방법

* 사전 작업 (인터넷을 사용 할 수 있는 환경에서만 동작합니다.)
   - 패키지 설치
      + git
      + podman
     > yum install git podman
     
   - git 클론
      ```bash
      git clone https://github.com/whalsrb100/envPxe.git
      ```
   - script 수정
     ```bash
     ]# cat pxe_all-in-one.sh
     ...생략...
     MyTag='v1.0'                      ### 태그명 설정
     ################################################################
     # PXE SERVER POD
     ################################################################
     HTTPD_DOCUMENT_DIR='/var/www/html'     ### 아파치 홈 경로 설정
     TFTPBOOT_HOME_DIR='/var/lib/tftpboot'  ### TFTP 서버 홈 경로 설정
     HTTPD_PORT=80
     DHCPD_PORT1=67
     DHCPD_PORT2=68
     TFTP_PORT=69
     DEFAULT_LEASES_TIME=6000 ### Seconds
     MAX_LEASES_TIME=7200     ### Seconds
     NETWORK=1.2.3.0          ### NETWORK ID
     SUBNET=255.255.255.0     ### 24 bit
     ROUTERS=1.2.3.2          ### GATEWAY IP
     NEXT_SERVER=1.2.3.2      ### TFTP-SERVER IP
     RANGE_START=1.2.3.100    ### DHCP POOL START
     RANGE_END=1.2.3.200      ### DHCP POOL END
     MyImageName='mj-alpine-pxe'           ### 이미지 이름 설정
     IMAGE_origin=docker.io/library/alpine:latest ## 원본이미지
     IMAGE_custom=localhost/${MyImageName}
     ...생략...
     ```
> 위 내용을 본인의 환경에 맞게 설정을 수정합니다.

   - script 수행
     ```bash
     cd envPxe/
     sh pxe_all-in-one.sh
     ```
     > 스크립트 수행 시 환경작성이 수행되고, 구동/중지/재시작 명령어가 터미널에 출력되며, 이후 인터넷이 없어도 잘 동작 합니다.

## 시작 명령어
```bash
podman run --privileged -dit --rm -v <TFTP호스트경로>:/var/tftpboot -v <HTML호스트경로>:/var/www/localhost/htdocs -p 69:69 -p 67:67 -p 68:68 -p 80:80 --network host --name <POD이름> <이미지명>:<태그명>
```
> 구동 시 privileged 와 network host 옵션이 추가 되어있어 포트 바인딩은 하지 않아도 잘 동작합니다.

> (-p 69:69 -p 67:67 -p 68:68 -p 80:80 ==> 하지 않아도 잘 동작 합니다.)

## 중지 명령어
```bash
podman exec -it <POD이름> killall -9 sleep
```

## 재시작 명령어 (아파치 홈 경로 이하 iso 이미지 마운트 시 수행 필요)
```bash
podman restart <POD이름>
```
> 아파치 홈 경로 이하로 `iso 이미지`를 마운트 하는 경우 POD 의 재구동 이후 정상 접근이 가능합니다.
