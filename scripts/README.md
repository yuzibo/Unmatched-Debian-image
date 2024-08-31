The script has been tested on debian/sid

```bash
sudo ./mkimg-unmatched-debian.sh
```

User: debian

passwd: debian

This script ultimately generates a rootfs for nvme. Of course you can also modify it slightly to generate a rootfs for sd.

From [Installing Debian on HiFive](https://wiki.debian.org/InstallingDebianOn/SiFive/%20HiFiveUnmatched#Installing_Debian_on_HiFive), if you boot from SD card, you need flash bootloader into sd also.

The bootloader [image](https://github.com/yuzibo/Unmatched-Debian-image/releases/download/0.0.4/sd-uboot.img) you can download and to flash it into sd card.
