# envPxe
Create Environments for PXE 

## Running Command
``` bash
podman run --privileged -dit --rm -v /var/lib/tftpboot:/var/tftpboot -p 69:69 -p 67:67 -p 68:68 --network host --name mj-pxe localhost/mj-alpine-pxe:v1.0
```

## Stopping Command
```bash
podman exec -it mj-pxe killall sleep
```
