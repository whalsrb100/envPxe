# PXE 환경 작성 내용 입니다.

* 사전 작업 (인터넷을 사용 할 수 있는 환경에서만 동작합니다.)
   - 패키지 설치
      1. git
      2. podman
   - git 클론
      ```bash
      git clone https://github.com/whalsrb100/envPxe.git
      ```
   - script 수행
     ```bash
     cd envPxe/
     sh pxe_all-in-one.sh
     ```
     >> 스크립트 수행 시 환경작성이 수행되고, 구동/중지/재시작 명령어가 터미널에 출력되며, 이후 인터넷이 없어도 잘 동작 합니다.


* 출력 된 명령어를 수행하여 구동을 시킬 수 있습니다.
## Running Command
``` bash
podman run --privileged -dit --rm -v <TFTP호스트경로>:/var/tftpboot -v <HTML호스트경로>:/var/www/localhost/htdocs -p 69:69 -p 67:67 -p 68:68 -p 80:80 --network host --name <POD이름> localhost/mj-alpine-pxe:v1.0
```

## Stopping Command
```bash
podman exec -it <POD이름> killall -9 sleep
```

## Restartind Command
```bash
podman restart <POD이름>
```
