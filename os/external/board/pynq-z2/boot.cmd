setenv bootargs console=ttyPS0,115200 root=/dev/mmcblk0p2 rw rootwait uio_pdrv_genirq.of_id=generic-uio
fatload mmc 0:1 0x1000000 system.bin
fpga load 0 0x1000000 ${filesize}
fatload mmc 0:1 0x2000000 uImage
fatload mmc 0:1 0x2a00000 system.dtb
bootm 0x2000000 - 0x2a00000
