# Update

Now you can use [mkimg-unmatched-debian.sh](./scripts/mkimg-unmatched-debian.sh) to generate one rootfs for nvme, more defail please see [README](./scripts/README.md)

2024/08/28

Now some changes from Debian lead to the image for Unmatched [pre-built](https://wiki.debian.org/InstallingDebianOn/SiFive/%20HiFiveUnmatched#Preparing_disk_image) does not work.

You can download the refreshed image for nvme from my personally [site](http://vimer.7766.org:63015/images/Unmatched-debian/). The `user&passwd` is `rv:rv`.

# Depends
```bash
sudo apt install -y qemu-user-static qemu-system qemu-utils qemu-system-misc binfmt-support
```

# How to build image
Need docker docker-compose installed, then type:
```bash
sudo DOCKER_BUILDKIT=1 docker-compose build nvme
sudo docker-compose up nvme
```
Or:
```bash
sudo make unmatched
```
Two image files will be generated into `image`:

```bash
nvme-rootfs.img.xz  sd-uboot.img
```

# How to install image
The `nvme-rootfs.img` you can use cmd below to flash to nvme:

```bash
sudo dd if=nvme-rootfs.img of=/dev/[nvme-device] bs=64k iflag=fullblock oflag=direct conv=fsync status=progress
```

If the bootloader you want to use it that in sd card, you can `dd` the `sd-uboot.img` to sd card:
```bash
sudo dd if=sd-uboot.img of=/dev/[sd-device] bs=64k iflag=fullblock oflag=direct conv=fsync status=progress
```

# Username and passwd
```
user: root, passwd: sifive
user: rv,   passwd: rv
```

Once you boot the system, maybe the first thing is `sudo apt update && upgrade`.

# Install Desktop
First you need to have a graphics card, such as amd radeon(soft lockup issue when boot) like me, then run:
```bash
sudo apt install firmware-amd-graphics
```

You need add `non-free-firmware` component in sources.list file.

# Increase nvme disk  
Maye you need reszie nvme volume with cmd below:

```
parted -f -s /dev/nvme0n1 print
echo 'yes' | parted ---pretend-input-tty /dev/nvme0n1 resizepart 1 100% 
resize2fs /dev/nvme0n1p1
```
(Better to reboot after this operation)

# sync time
If you see the info after `apt update`:

```
E: Release file for https://mirror.iscas.ac.cn/debian-ports/dists/sid/InRelease is not valid yet (invalid for another 48d 6h 38min 42s).
```
Please fix it by `ntpdate`:

```
sudo ntpdate cn.pool.ntp.org
```

# Thanks

Thanks to [wangliu-iscas](https://github.com/wangliu-iscas) for testing.

Thanks to shiputx@gmail.com and he is co-author also.

The code demo I learn from [d1_build](https://github.com/tmolteno/d1_build)
