#!/bin/bash

MyTag='v1.0'
################################################################
# PXE SERVER POD
################################################################
HTTPD_DOCUMENT_DIR='/var/www/html'
TFTPBOOT_HOME_DIR='/var/lib/tftpboot'
HTTPD_PORT='80'
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
MyImageName='mj-alpine-pxe'
IMAGE_origin=docker.io/library/alpine:latest
IMAGE_custom=localhost/${MyImageName}

podman rmi -f ${IMAGE_custom}:${MyTag} > /dev/null 2>&1

echo "FROM ${IMAGE_origin}" > Dockerfile
echo "RUN apk add dhcp tftp-hpa apache2 && echo -e '#!/bin/sh\nsleep 3\nin.tftpd -4 -v -L -s /var/tftpboot &' >> /entrypoint.sh && chmod 755 /entrypoint.sh && echo -e \"allow booting;\nallow bootp;\n\nddns-update-style none;\ndefault-lease-time ${DEFAULT_LEASES_TIME};\nmax-lease-time ${MAX_LEASES_TIME};\n\noption subnet-mask ${SUBNET};\noption routers ${ROUTERS};\n\n#option magic code 208 = string;\n#option configfile code 209 = text;\n#option pathprefix code 210 = text;\n#option reboottime code 211 = unsigned integer 32;\noption arch code 93 = unsigned integer 16; #RFC4578\n\nsubnet ${NETWORK} netmask ${SUBNET}\n{\n        range ${RANGE_START} ${RANGE_END};\n        next-server ${NEXT_SERVER};\n\n        if option arch = 00:07 {\n            filename \\\"/pxelinux/grubx64.efi\\\";\n        }else{\n            filename \\\"pxelinux.0\\\";\n        }\n}\" > /etc/dhcp/dhcpd.conf && echo -e \"sleep 3\n/usr/sbin/dhcpd -f -cf /etc/dhcp/dhcpd.conf -user dhcp -group dhcp --no-pid &\" >> /entrypoint.sh && echo 'sed -i \\\"s/^#ServerName .*/ServerName localhost/g\\\" /etc/apache2/httpd.conf' >> /entrypoint.sh && echo '/usr/sbin/httpd;sleep infinity' >> /entrypoint.sh && touch /var/lib/dhcp/dhcpd.leases && chown dhcp:dhcp /var/lib/dhcp/dhcpd.leases" >> Dockerfile
echo 'ENTRYPOINT ["/entrypoint.sh"]' >> Dockerfile

podman build --no-cache --tag ${IMAGE_origin} -f Dockerfile
rm -f Dockerfile

podman tag ${IMAGE_origin} ${IMAGE_custom}:${MyTag}
podman rmi ${IMAGE_origin}

POD_NAME='mj-pxe'
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
echo "[STOP COMMAND]"
echo "podman exec -it mj-pxe killall sleep"
echo "#=================================================="
################################################################
