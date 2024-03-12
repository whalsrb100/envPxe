# envPxe
Create Environments for PXE 

## Running Command
``` bash
podman run --privileged -dit --rm -v /var/lib/tftpboot:/var/tftpboot -v /var/www/html:/var/www/localhost/htdocs -p 69:69 -p 67:67 -p 68:68 -p 80:80 --network host --name mj-pxe localhost/mj-alpine-pxe:v1.0
```

## Stopping Command
```bash
podman exec -it mj-pxe killall -9 sleep
```
