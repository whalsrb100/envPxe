#!/bin/bash
################################################################
# PXE SERVER POD
################################################################
HTTPD_DOCUMENT_DIR=/var/www/html
TFTPBOOT_HOME_DIR=/var/lib/tftpboot
    NETWORK=1.2.3.0       ### NETWORK ID
     SUBNET=255.255.255.0 ### 24 bit
RANGE_START=1.2.3.100     ### DHCP POOL START
  RANGE_END=1.2.3.200     ### DHCP POOL END
    ROUTERS=1.2.3.2       ### GATEWAY IP
NEXT_SERVER=1.2.3.2       ### TFTP-SERVER IP
MyImageName='oh_my_pxe_image'     ### 이미지이름
POD_NAME='oh_my_pxe'          ### 파드이름(컨테이너이름)
MyTag='v0.1'             ### 태그명

SET_TFTP_SERVER="true"
SET_DHCP_SERVER="true"
SET_HTTP_SERVER="true"
################################################################
HTTPD_PORT=80
DHCPD_PORT1=67
DHCPD_PORT2=68
TFTP_PORT=69
DEFAULT_LEASES_TIME=6000 ### Seconds
MAX_LEASES_TIME=7200     ### Seconds
IMAGE_origin=docker.io/library/alpine:latest
IMAGE_custom=localhost/${MyImageName}
################################################################

podman rmi -f ${IMAGE_custom}:${MyTag} > /dev/null 2>&1

TFTPD_PKG=
DHCPD_PKG=
HTTPD_PKG=
[ "${SET_TFTP_SERVER}" == "true" ] && TFTPD_PKG="tftp-hpa"
[ "${SET_DHCP_SERVER}" == "true" ] && DHCPD_PKG="dhcp"
[ "${SET_HTTP_SERVER}" == "true" ] && HTTPD_PKG="apache2"
INSTALL_PKG="${TFTP_PKG} ${HTTPD_PKG} ${DHCPD_PKG}"

HTTPD_PRE=
DHCPD_PRE=
[ "${SET_DHCP_SERVER}" == "true" ] &&  DHCPD_PRE='touch /var/lib/dhcp/dhcpd.leases; chown dhcp:dhcp /var/lib/dhcp/dhcpd.leases;'
[ "${SET_HTTP_SERVER}" == "true" ] && HTTPD_PRE='sed -i "s/^#ServerName .*/ServerName localhost/g" /etc/apache2/httpd.conf;'
PRE_CMD="${HTTPD_PRE}${DHCPD_PRE}"

[ "${SET_DHCP_SERVER}" == "true" ] &&  DHCPD_CONF="allow booting;\nallow bootp;\n\nddns-update-style none;\ndefault-lease-time ${DEFAULT_LEASES_TIME};\nmax-lease-time ${MAX_LEASES_TIME};\n\noption subnet-mask ${SUBNET};\noption routers ${ROUTERS};\n\n#option magic code 208 = string;\n#option configfile code 209 = text;\n#option pathprefix code 210 = text;\n#option reboottime code 211 = unsigned integer 32;\noption arch code 93 = unsigned integer 16; #RFC4578\n\nsubnet ${NETWORK} netmask ${SUBNET}\n{\n        range ${RANGE_START} ${RANGE_END};\n        next-server ${NEXT_SERVER};\n\n        if option arch = 00:07 {\n            filename \\\"/pxelinux/grubx64.efi\\\";\n        }else{\n            filename \\\"pxelinux.0\\\";\n        }\n}"

SHABANG='#!/bin/sh'
TFTPD_EXEC=
DHCPD_EXEC=
HTTPD_EXEC=
[ "${SET_TFTP_SERVER}" == "true" ] && TFTPD_EXEC='in.tftpd -4 -v -L -s /var/tftpboot &'
[ "${SET_DHCP_SERVER}" == "true" ] &&  DHCPD_EXEC='/usr/sbin/dhcpd -f -cf /etc/dhcp/dhcpd.conf -user dhcp -group dhcp --no-pid &'
[ "${SET_HTTP_SERVER}" == "true" ] && HTTPD_EXEC='httpd'
ENTRYPOINT_EXEC='sleep infinity'

ENTRYPOINT_CMD="${SHABANG}\n${TFTPD_EXEC}\n${DHCPD_EXEC}\n${HTTPD_EXEC}\n${ENTRYPOINT_EXEC}"
ENTRYPOINT_NAME='/entrypoint.sh'
ENTRYPOINT_PERMISSION_SET="chmod 755 ${ENTRYPOINT_NAME}"

echo "FROM ${IMAGE_origin}" > Dockerfile
echo -n "RUN apk add ${INSTALL_PKG} && " >> Dockerfile
echo -n "${PRE_CMD} " >> Dockerfile
[ "${SET_DHCP_SERVER}" == "true" ] && echo -n "echo -e \"$(echo ${DHCPD_CONF})\" && " >> Dockerfile
echo -n "echo ${ENTRYPOINT_CMD} > ${ENTRYPOINT_NAME} && " >> Dockerfile
echo "${ENTRYPOINT_PERMISSION_SET}" >> Dockerfile
echo 'ENTRYPOINT ["/entrypoint.sh"]' >> Dockerfile


#echo "FROM ${IMAGE_origin}" > Dockerfile
#echo "RUN apk add dhcp tftp-hpa apache2 && echo -e '#!/bin/sh\nsleep 3\nin.tftpd -4 -v -L -s /var/tftpboot &' >> /entrypoint.sh && chmod 755 /entrypoint.sh && echo -e \"allow booting;\nallow bootp;\n\nddns-update-style none;\ndefault-lease-time ${DEFAULT_LEASES_TIME};\nmax-lease-time ${MAX_LEASES_TIME};\n\noption subnet-mask ${SUBNET};\noption routers ${ROUTERS};\n\n#option magic code 208 = string;\n#option configfile code 209 = text;\n#option pathprefix code 210 = text;\n#option reboottime code 211 = unsigned integer 32;\noption arch code 93 = unsigned integer 16; #RFC4578\n\nsubnet ${NETWORK} netmask ${SUBNET}\n{\n        range ${RANGE_START} ${RANGE_END};\n        next-server ${NEXT_SERVER};\n\n        if option arch = 00:07 {\n            filename \\\"/pxelinux/grubx64.efi\\\";\n        }else{\n            filename \\\"pxelinux.0\\\";\n        }\n}\" > /etc/dhcp/dhcpd.conf && echo -e \"sleep 3\n/usr/sbin/dhcpd -f -cf /etc/dhcp/dhcpd.conf -user dhcp -group dhcp --no-pid &\" >> /entrypoint.sh && echo 'sed -i \\\"s/^#ServerName .*/ServerName localhost/g\\\" /etc/apache2/httpd.conf' >> /entrypoint.sh && echo '/usr/sbin/httpd;sleep infinity' >> /entrypoint.sh && touch /var/lib/dhcp/dhcpd.leases && chown dhcp:dhcp /var/lib/dhcp/dhcpd.leases" >> Dockerfile
#echo 'ENTRYPOINT ["/entrypoint.sh"]' >> Dockerfile

podman build --no-cache --tag ${IMAGE_origin} -f Dockerfile
rm -f Dockerfile

podman tag ${IMAGE_origin} ${IMAGE_custom}:${MyTag}
podman rmi ${IMAGE_origin}


IMG_NAME="${IMAGE_custom}:${MyTag}"
echo "#=================================================="
echo "[START COMMAND]"
echo "podman run --privileged \
-dit --rm \
-v ${TFTPBOOT_HOME_DIR}:/var/tftpboot \
-v ${HTTPD_DOCUMENT_DIR}:/var/www/localhost/htdocs \
-p ${TFTP_PORT}:69 \
-p ${DHCPD_PORT1}:67 -p ${DHCPD_PORT2}:68 \
-p ${HTTPD_PORT}:80 \
--network host --name ${POD_NAME} ${IMG_NAME}"
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
