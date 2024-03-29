#!/bin/bash
################################################################
# SELECT SERVERS
################################################################
# "true" or "not true"
USE_TFTP_SERVER="true" ### TFTP Server 사용(true)/미사용(false) 설정
USE_DHCP_SERVER="true" ### DHCP Server 사용(true)/미사용(false) 설정
USE_HTTP_SERVER="true" ### HTTP Server 사용(true)/미사용(false) 설정
OVERWRITE_NEW_SYSLINUX="true" ### syslinux 파일을 새로 받아와 오버라이트
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
[ "${OVERWRITE_NEW_SYSLINUX}" == "true" ] && [ "${USE_TFTP_SERVER}" == "true" ] && TFTPD_PKG+=" syslinux"
[ "${USE_DHCP_SERVER}" == "true" ] && DHCPD_PKG="dhcp"
[ "${USE_HTTP_SERVER}" == "true" ] && HTTPD_PKG="apache2"
INSTALL_PKG="${TFTPD_PKG} ${HTTPD_PKG} ${DHCPD_PKG}"

[ "${USE_DHCP_SERVER}" == "true" ] && DHCPD_PRE='touch /var/lib/dhcp/dhcpd.leases; chown dhcp:dhcp /var/lib/dhcp/dhcpd.leases;'
[ "${USE_HTTP_SERVER}" == "true" ] && HTTPD_PRE='sed -i "s/^#ServerName .*/ServerName localhost/g" /etc/apache2/httpd.conf;'
PRE_CMD="${HTTPD_PRE}${DHCPD_PRE}"

[ "${USE_DHCP_SERVER}" == "true" ] && GRUB_EFI_FILE='/grubx64.efi'
[ "${USE_DHCP_SERVER}" == "true" ] && GRUB_LEGACY_FILE='pxelinux.0'
[ "${USE_DHCP_SERVER}" == "true" ] && DHCPD_CONF="allow booting;\nallow bootp;\n\nddns-update-style none;\ndefault-lease-time ${DEFAULT_LEASES_TIME};\nmax-lease-time ${MAX_LEASES_TIME};\n\noption subnet-mask ${SUBNET};\noption routers ${ROUTERS};\n\n#option magic code 208 = string;\n#option configfile code 209 = text;\n#option pathprefix code 210 = text;\n#option reboottime code 211 = unsigned integer 32;\noption arch code 93 = unsigned integer 16; #RFC4578\n\nsubnet ${NETWORK} netmask ${SUBNET}\n{\n        range ${RANGE_START} ${RANGE_END};\n        next-server ${NEXT_SERVER};\n\n        if option arch = 00:07 {\n            filename \\\"${GRUB_EFI_FILE}\\\";\n        }else{\n            filename \\\"${GRUB_LEGACY_FILE}\\\";\n        }\n}"

ENTRYPOINT_CMD='#!/bin/sh\n'

[ "${OVERWRITE_NEW_SYSLINUX}" == "true" ] && [ "${USE_TFTP_SERVER}" == "true" ] && ENTRYPOINT_CMD+='[ ! -d "/var/tftpboot/pxelinux.cfg"  ] && mkdir /var/tftpboot/pxelinux.cfg/\n'
[ "${OVERWRITE_NEW_SYSLINUX}" == "true" ] && [ "${USE_TFTP_SERVER}" == "true" ] && ENTRYPOINT_CMD+='[ ! -f "/var/tftpboot/ldlinux.c32"  ] && cp /usr/share/syslinux/ldlinux.c32  /var/tftpboot/\n'
[ "${OVERWRITE_NEW_SYSLINUX}" == "true" ] && [ "${USE_TFTP_SERVER}" == "true" ] && ENTRYPOINT_CMD+='[ ! -f "/var/tftpboot/libcom32.c32" ] && cp /usr/share/syslinux/libcom32.c32 /var/tftpboot/\n'
[ "${OVERWRITE_NEW_SYSLINUX}" == "true" ] && [ "${USE_TFTP_SERVER}" == "true" ] && ENTRYPOINT_CMD+='[ ! -f "/var/tftpboot/libutil.c32"  ] && cp /usr/share/syslinux/libutil.c32  /var/tftpboot/\n'
[ "${OVERWRITE_NEW_SYSLINUX}" == "true" ] && [ "${USE_TFTP_SERVER}" == "true" ] && ENTRYPOINT_CMD+='[ ! -f "/var/tftpboot/memdisk"      ] && cp /usr/share/syslinux/memdisk      /var/tftpboot/\n'
[ "${OVERWRITE_NEW_SYSLINUX}" == "true" ] && [ "${USE_TFTP_SERVER}" == "true" ] && ENTRYPOINT_CMD+='[ ! -f "/var/tftpboot/menu.c32"     ] && cp /usr/share/syslinux/menu.c32     /var/tftpboot/\n'
[ "${OVERWRITE_NEW_SYSLINUX}" == "true" ] && [ "${USE_TFTP_SERVER}" == "true" ] && ENTRYPOINT_CMD+='[ ! -f "/var/tftpboot/pxelinux.0"   ] && cp /usr/share/syslinux/pxelinux.0   /var/tftpboot/\n'
[ "${OVERWRITE_NEW_SYSLINUX}" == "true" ] && [ "${USE_TFTP_SERVER}" == "true" ] && ENTRYPOINT_CMD+='[ ! -f "/var/tftpboot/vesamenu.c32" ] && cp /usr/share/syslinux/vesamenu.c32 /var/tftpboot/\n'
[ "${OVERWRITE_NEW_SYSLINUX}" == "true" ] && [ "${USE_TFTP_SERVER}" == "true" ] && ENTRYPOINT_CMD+='[ ! -f "/var/tftpboot/cmenu.c32"    ] && cp /usr/share/syslinux/cmenu.c32    /var/tftpboot/\n'
[ "${OVERWRITE_NEW_SYSLINUX}" == "true" ] && [ "${USE_TFTP_SERVER}" == "true" ] && ENTRYPOINT_CMD+='[ ! -f "/var/tftpboot/pxelinux.cfg/default"  ] && echo -e \"default menu.c32\\\nprompt 0\\\ntimeout 0\\\n\\\nMENU TITLE titleName\\\nLABEL selectMenu1\\\nKERNEL \\\"VMLINUZ FilePath\\\"\\\nAPPEND ksdevice=bootif initrd=\\\"INITRD IMG Path\\\" network vnc vncconnect=\\\"VNCConnectIP\\\":5500 method/ks=\\\"protocol://Address/URI/kickStartFilePath\\\"\\\nIPAPPEND 2\" > /var/tftpboot/pxelinux.cfg/default\n'
[ "${OVERWRITE_NEW_SYSLINUX}" == "true" ] && [ "${USE_TFTP_SERVER}" == "true" ] && ENTRYPOINT_CMD+='[ ! -f "/var/tftpboot/grub.cfg"  ] && echo -e \"set default=\\\"0\\\"\\\n\\\nfunction load_video {\\\n  insmod efi_gop\\\n  insmod efi_uga\\\n  insmod video_bochs\\\n  insmod video_cirrus\\\n  insmod all_video\\\n}\\\nload_video\\\nset gfxpayload=keep\\\ninsmod gzio\\\ninsmod part_gpt\\\ninsmod ext2\\\n\\\nset timeout=60\\\n### END /etc/grub.d/00_header ###\\\nsearch --no-floppy --set=root -l \\\"CentOS-8-4-2105-x86_64-dvd\\\"\\\n### BEGIN /etc/grub.d/10_linux ###\\\n\\\nmenuentry \\\"R84-NH - kickstart\\\" --class fedora --class gnu-linux --class gnu --class os {\\\n        linuxefi <vmlinuz Path> network vnc vncconnect=<IP>:5500 inst.ks=http://<IP>/<PATH>/<KickstartFile>\\\n        initrdefi /<INITRD PATH>\\\n}\" > /var/tftpboot/grub.cfg\n'




[ "${USE_TFTP_SERVER}" == "true" ] && ENTRYPOINT_CMD+='in.tftpd -4 -v -L -s /var/tftpboot &\n'
[ "${USE_DHCP_SERVER}" == "true" ] && ENTRYPOINT_CMD+='/usr/sbin/dhcpd -f -cf /etc/dhcp/dhcpd.conf -user dhcp -group dhcp --no-pid &\n'
[ "${USE_HTTP_SERVER}" == "true" ] && ENTRYPOINT_CMD+='httpd\n'
ENTRYPOINT_CMD+='sleep infinity\n'

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
([ "${USE_DHCP_SERVER}" == "true" ] || [ "${USE_TFTP_SERVER}" == "true" ]) && echo -e "\n\n\n"
([ "${USE_DHCP_SERVER}" == "true" ] || [ "${USE_TFTP_SERVER}" == "true" ]) && echo '#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
([ "${USE_DHCP_SERVER}" == "true" ] || [ "${USE_TFTP_SERVER}" == "true" ]) && echo "Check Exists files in container ${POD_NAME} (1/2). - For Legacy: ${TFTPBOOT_HOME_DIR}/${GRUB_LEGACY_FILE}"
([ "${USE_DHCP_SERVER}" == "true" ] || [ "${USE_TFTP_SERVER}" == "true" ]) && echo "Check Exists files in container ${POD_NAME}(2/2). - For UEFI: ${TFTPBOOT_HOME_DIR}${GRUB_EFI_FILE}"
([ "${USE_DHCP_SERVER}" == "true" ] || [ "${USE_TFTP_SERVER}" == "true" ]) && echo '#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
([ "${USE_DHCP_SERVER}" == "true" ] || [ "${USE_TFTP_SERVER}" == "true" ]) && echo -e "\n\n\n"

PrintCmds="podman run --privileged -itd --rm"
[ "${USE_TFTP_SERVER}" == "true" ] && PrintCmds+=" -v ${TFTPBOOT_HOME_DIR}:/var/tftpboot -p ${EXT_TFTP_PORT}:69 "
[ "${USE_HTTP_SERVER}" == "true" ] && PrintCmds+=" -v ${HTTPD_DOCUMENT_DIR}:/var/www/localhost/htdocs -p ${EXT_HTTPD_PORT}:80 "
[ "${USE_DHCP_SERVER}" == "true" ] && PrintCmds+=" -p ${EXT_DHCPD_PORT1}:67 -p ${EXT_DHCPD_PORT2}:68 "
PrintCmds+="--network host --name ${POD_NAME} ${IMG_NAME}"
echo "[START COMMAND]"
FileName=${POD_NAME}_start.sh
echo '#!/bin/bash' > ${FileName}
echo "TFTPBOOT_HOME_DIR=${TFTPBOOT_HOME_DIR}" >> ${FileName}
echo "HTTPD_DOCUMENT_DIR=${HTTPD_DOCUMENT_DIR}" >> ${FileName}
echo "EXT_TFTP_PORT=${EXT_TFTP_PORT}"  >> ${FileName}
echo "EXT_HTTPD_PORT=${EXT_HTTPD_PORT}"  >> ${FileName}
echo "EXT_DHCPD_PORT1=${EXT_DHCPD_PORT1}"  >> ${FileName}
echo "EXT_DHCPD_PORT2=${EXT_DHCPD_PORT2}"  >> ${FileName}
echo >> ${FileName}
echo "podman run --privileged -itd --rm --network host --name ${POD_NAME} \\" >> ${FileName}
echo "    -v \${TFTPBOOT_HOME_DIR}:/var/tftpboot -p \${EXT_TFTP_PORT}:69 \\" >> ${FileName}
echo "    -v \${HTTPD_DOCUMENT_DIR}:/var/www/localhost/htdocs -p \${EXT_HTTPD_PORT}:80 \\" >> ${FileName}
echo "    -p \${EXT_DHCPD_PORT1}:67 -p \${EXT_DHCPD_PORT2}:68  \\" >> ${FileName}
echo "    ${IMG_NAME}" >> ${FileName}

echo "${PrintCmds}"
chmod 755 ${POD_NAME}_start.sh
echo "#=================================================="

echo "#=================================================="
echo "[RESTART COMMAND]"
echo "podman restart ${POD_NAME}" | tee ${POD_NAME}_restart.sh
chmod 755 ${POD_NAME}_restart.sh
echo "#=================================================="

echo "#=================================================="
echo "[STOP COMMAND]"
echo "podman exec -it ${POD_NAME} killall sleep" | tee ${POD_NAME}_stop.sh
chmod 755 ${POD_NAME}_stop.sh
echo "#=================================================="
################################################################
