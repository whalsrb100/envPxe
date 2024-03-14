#!/bin/bash
################################################################
# SELECT SERVERS
################################################################
# "true" or "not true"
USE_TFTP_SERVER="true" ### TFTP Server 사용(true)/미사용(false) 설정
USE_DHCP_SERVER="true" ### DHCP Server 사용(true)/미사용(false) 설정
USE_HTTP_SERVER="true" ### HTTP Server 사용(true)/미사용(false) 설정
################################################################

################################################################
# PXE SERVER POD
################################################################
#----------------------------------------------#
### Image/Pod Naming ###
#----------------------------------------------#
 MyImageName='oh_my_pxe_image' ### 이미지이름
    POD_NAME='oh_my_pxe'   ### 파드이름(컨테이너이름)
       MyTag='v0.1'    ### 태그명
IMAGE_origin=docker.io/library/alpine:latest ### Basic Image
#----------------------------------------------#
#----------------------------------------------#
### Apache Arguments ###
#----------------------------------------------#
HTTPD_DOCUMENT_DIR=/var/www/html ### Host 의 Apache 홈 경로
EXT_HTTPD_PORT=80 # No modify
#----------------------------------------------#
#----------------------------------------------#
### TFTP Arguments  ###
#----------------------------------------------#
TFTPBOOT_HOME_DIR=/var/lib/tftpboot ### Host 의 TFTP 홈 경로
EXT_TFTP_PORT=69 ### No modify
#----------------------------------------------#
#----------------------------------------------#
### DHCP Arguments  ###
#----------------------------------------------#
    NETWORK=1.2.3.0       ### NETWORK ID
     SUBNET=255.255.255.0 ### 24 bit
RANGE_START=1.2.3.100     ### DHCP POOL START
  RANGE_END=1.2.3.200     ### DHCP POOL END
    ROUTERS=1.2.3.2       ### GATEWAY IP
NEXT_SERVER=1.2.3.2       ### TFTP-SERVER IP

DEFAULT_LEASES_TIME=6000  ### Seconds
    MAX_LEASES_TIME=7200  ### Seconds

EXT_DHCPD_PORT1=67 ### No modify
EXT_DHCPD_PORT2=68 ### No modify
#----------------------------------------------#
################################################################
IMAGE_custom=localhost/${MyImageName}

if [ "${USE_TFTP_SERVER}" != "true" ] && [ "${USE_DHCP_SERVER}" != "true" ] && [ "${USE_HTTP_SERVER}" != "true" ];then
    echo
    cat ${0} | grep ^USE_[TDH][FHT][TC]P_SERVER=
    echo
    echo 'not use Servers, no create server image'
    exit 1
fi

podman rmi -f ${IMAGE_custom}:${MyTag} > /dev/null 2>&1
################################################################
# Create Settings
################################################################
[ "${USE_TFTP_SERVER}" == "true" ] && TFTPD_PKG="tftp-hpa"
[ "${USE_DHCP_SERVER}" == "true" ] && DHCPD_PKG="dhcp"
[ "${USE_HTTP_SERVER}" == "true" ] && HTTPD_PKG="apache2"
INSTALL_PKG="${TFTPD_PKG} ${HTTPD_PKG} ${DHCPD_PKG}"

[ "${USE_DHCP_SERVER}" == "true" ] && DHCPD_PRE='touch /var/lib/dhcp/dhcpd.leases; chown dhcp:dhcp /var/lib/dhcp/dhcpd.leases;'
[ "${USE_HTTP_SERVER}" == "true" ] && HTTPD_PRE='sed -i "s/^#ServerName .*/ServerName localhost/g" /etc/apache2/httpd.conf;'
PRE_CMD="${HTTPD_PRE}${DHCPD_PRE}"

[ "${USE_DHCP_SERVER}" == "true" ] && DHCPD_CONF="allow booting;\nallow bootp;\n\nddns-update-style none;\ndefault-lease-time ${DEFAULT_LEASES_TIME};\nmax-lease-time ${MAX_LEASES_TIME};\n\noption subnet-mask ${SUBNET};\noption routers ${ROUTERS};\n\n#option magic code 208 = string;\n#option configfile code 209 = text;\n#option pathprefix code 210 = text;\n#option reboottime code 211 = unsigned integer 32;\noption arch code 93 = unsigned integer 16; #RFC4578\n\nsubnet ${NETWORK} netmask ${SUBNET}\n{\n        range ${RANGE_START} ${RANGE_END};\n        next-server ${NEXT_SERVER};\n\n        if option arch = 00:07 {\n            filename \\\"/pxelinux/grubx64.efi\\\";\n        }else{\n            filename \\\"pxelinux.0\\\";\n        }\n}"

SHABANG='#!/bin/sh'
[ "${USE_TFTP_SERVER}" == "true" ] && TFTPD_EXEC='in.tftpd -4 -v -L -s /var/tftpboot &'
[ "${USE_DHCP_SERVER}" == "true" ] && DHCPD_EXEC='/usr/sbin/dhcpd -f -cf /etc/dhcp/dhcpd.conf -user dhcp -group dhcp --no-pid &'
[ "${USE_HTTP_SERVER}" == "true" ] && HTTPD_EXEC='httpd'
ENTRYPOINT_EXEC='sleep infinity'

ENTRYPOINT_CMD="${SHABANG}\n${TFTPD_EXEC}\n${DHCPD_EXEC}\n${HTTPD_EXEC}\n${ENTRYPOINT_EXEC}"
ENTRYPOINT_NAME='/entrypoint.sh'
ENTRYPOINT_PERMISSION_SET="chmod 755 ${ENTRYPOINT_NAME}"
################################################################

echo "FROM ${IMAGE_origin}" > Dockerfile
echo -n "RUN apk add ${INSTALL_PKG} && " >> Dockerfile
echo -n "${PRE_CMD} " >> Dockerfile
[ "${USE_DHCP_SERVER}" == "true" ] && echo -n "echo -e \"$(echo ${DHCPD_CONF})\" > /etc/dhcp/dhcpd.conf && " >> Dockerfile
echo -n "echo -e \"${ENTRYPOINT_CMD}\" > ${ENTRYPOINT_NAME} && " >> Dockerfile
echo "${ENTRYPOINT_PERMISSION_SET}" >> Dockerfile
echo 'ENTRYPOINT ["/entrypoint.sh"]' >> Dockerfile
podman build --no-cache --tag ${IMAGE_origin} -f Dockerfile
rm -f Dockerfile

podman tag ${IMAGE_origin} ${IMAGE_custom}:${MyTag}
podman rmi ${IMAGE_origin}


IMG_NAME="${IMAGE_custom}:${MyTag}"
echo "#=================================================="
PrintCmds="podman run --privileged -itd --rm"
[ "${USE_TFTP_SERVER}" == "true" ] && PrintCmds+=" -v ${TFTPBOOT_HOME_DIR}:/var/tftpboot -p ${EXT_TFTP_PORT}:69 "
[ "${USE_HTTP_SERVER}" == "true" ] && PrintCmds+=" -v ${HTTPD_DOCUMENT_DIR}:/var/www/localhost/htdocs -p ${EXT_HTTPD_PORT}:80 "
[ "${USE_DHCP_SERVER}" == "true" ] && PrintCmds+=" -p ${EXT_DHCPD_PORT1}:67 -p ${EXT_DHCPD_PORT2}:68 "
PrintCmds+="--network host --name ${POD_NAME} ${IMG_NAME}"
echo "[START COMMAND]"
echo "${PrintCmds}"
echo "#=================================================="

echo "#=================================================="
echo "[RESTART COMMAND]"
echo "podman restart ${POD_NAME}"
echo "#=================================================="

echo "#=================================================="
echo "[STOP COMMAND]"
echo "podman exec -it ${POD_NAME} killall sleep"
echo "#=================================================="
################################################################
