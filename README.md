# For detail information, check out my blog at: https://chieunhatnang.de/p/building-armbian-for-rockchip-rk3128/

## Quick installation notes for Armbian on RK3128

### Installation

Download the all the necessary files at : https://github.com/chieunhatnang-personal/RK3128-Linux-SupportingScripts/releases

#### Install and boot from SD Card
1. Prepare `idbloader.img`, `uboot.img`, `trust.img`, and `rootfs.img`.
2. Create an MBR partition table on the SD card.
3. Leave the first `16 MB` empty.

```shell
DEV=/dev/sdX
sudo parted -s "$DEV" mklabel msdos
sudo parted -s "$DEV" mkpart primary ext4 16MB 100%
sudo partprobe "$DEV"
```

4. Write `idbloader.img`, `uboot.img`, and `trust.img` to the raw device.
5. Write `rootfs.img` to the first partition.

```shell
sudo dd if=idbloader.img of="$DEV" seek=64 conv=fsync
sudo dd if=uboot.img of="$DEV" seek=16384 conv=fsync
sudo dd if=trust.img of="$DEV" seek=24576 conv=fsync
sudo dd if=rootfs.img of="${DEV}1" bs=4M status=progress conv=fsync
sync
```

6. Put the SD card into the board.
7. Boot the board from SD card.

You can use my script `bootcardmaker.sh` in the same release directory for easier process.


#### Install and boot from NAND/eMMC
1. Prepare `Loader` (`rkxx_loader_vx.xx.xxx.bin`), `parameter.txt`, `uboot.img`, `trust.img`, and `rootfs.img`.
2. Boot the board normally.
3. Connect a USB cable to the OTG port.
4. Open `RKDevTool v2.69`.
5. Go to `Advanced Function`.
6. Erase the first `0x10000` sectors with `Start LBA = 0x0` and `Count = 0x10000`.
7. Press `ResetDevice`.
8. Wait for the board to come back in `MaskROM` mode.
9. Go to `Download Image`.
10. Add the entries shown below.
![Install Armbian](Install1.png)
11. For a full NAND/eMMC install, flash `Loader`, `parameter`, `U-Boot`, `Trust`, and `rootfs`.

#### Hybrid install: U-boot on NAND/eMMC and rootfs on USB/SD Card
This is the layout I use most often. It is flexible, lets the system run from USB or SD card, and reinstalling the OS usually means rewriting only the external rootfs.

It is also useful when the internal NAND or eMMC is only partly damaged. A common symptom is that Android starts to boot and then hangs. In that case, the internal flash may still be good enough for `Loader`, `parameter`, `U-Boot`, and `Trust`, but not reliable enough for a full root filesystem.

The board still needs working internal NAND or eMMC for these bootloader pieces:
- `Loader`
- `parameter`
- `U-Boot`
- `Trust`

The rootfs lives on USB or SD card.

1. Follow steps `1` to `10` from the NAND/eMMC install above.
2. Flash only `Loader`, `parameter`, `U-Boot`, and `Trust` to the internal NAND or eMMC.
3. Do not flash `rootfs` to the internal storage.
4. Create a normal Linux partition on the USB drive or SD card.
5. Write `rootfs.img` to that partition, not to the whole device.

```shell
sudo dd if=rootfs.img of=/dev/sdX1 bs=4M status=progress conv=fsync
sync
```

6. Boot the board. It still starts from the internal NAND or eMMC, but the system itself can run from USB or SD card.

`Loader`, `parameter`, `U-Boot`, and `Trust` still come from the internal storage. The rootfs comes from USB or SD card.

One important detail: `rootfs.img` is not a full disk image. It is only a filesystem image. Write it to a partition such as `/dev/sdX1`, not to the whole disk. Tools like BalenaEtcher are the wrong fit here because they expect an image that already contains the full partition layout.

### Configuration
The rootfs starts with simple generic settings so it can boot on different board variants. After the first successful boot, connect Ethernet, `ssh` into the board, and run `rk3128-config`.

The main things worth checking are:
1. `RAM dynamic frequency`: enable it if you want better memory performance. It is off by default because some boards still hang with it enabled.
2. `Wi-Fi`: choose the correct Wi-Fi chip for the board. Then reboot and use `nmtui` to connect.
3. `SD Card`: if the board already boots from SD card, leave this alone. If you boot from another device and want the SD slot to work as storage, enable it here.
4. `Screen resolution`: the default is `1280x720`. If your display supports it, switch to `1920x1080` in the display menu.


### Manual configuration
The boot configuration lives in `/boot/armbianEnv.txt`.

This file is read by `boot.cmd` before the kernel starts. The format is simple:

```text
name=value
```

The main parameters used by this boot script are:

- `verbosity`: kernel log level. Default: `1`
- `console`: serial console device and baud rate. Default: `ttyS1,115200`
- `bootlogo`: enable or disable the boot splash. Default: `false`
- `logo`: if set to `disabled`, boot.cmd switches to `logo.nologo`
- `rootfstype`: root filesystem type. Default: `ext4`
- `docker_optimizations`: enable extra cgroup arguments for Docker. Default: `on`
- `mtdparts`: NAND/eMMC partition layout passed to the kernel. Default: it takes value from U-boot
- `overlay_prefix`: overlay filename prefix. Default: `rk3128`
- `partnum`: boot partition number. Default: it takes value from U-boot
- `fdtfile`: base device tree file to load, for example `rk3128-linux.dtb`
- `overlays`: space-separated list of built-in overlays to apply
- `user_overlays`: space-separated list of custom overlays from `/boot/overlay-user/`
- `rootdev`: override the detected root device.  Default: it takes value from U-boot
- `rootpartname`: NAND root partition name, used to build `/dev/rknand_<name>`.  Default: it takes value from U-boot
- `nandrootpartname`: explicit NAND root partition name override.  Default: it takes value from U-boot
- `extraargs`: extra kernel command-line arguments
- `extraboardargs`: more board-specific kernel arguments
- `usbstoragequirks`: USB storage quirks passed to the kernel

There are also a few automatic behaviors in this `boot.cmd`:

- If the board boots from eMMC, `emmc-enabled` is forced automatically.
- If the board boots from SD card, `sdcard-enabled` is forced automatically and `gpio2-sdcard-disabled` is removed.
- If the board boots from NAND, `emmc-enabled` is removed automatically.
- If neither `usb-otg-host` nor `usb-otg-peripheral` is selected, `usb-otg-host` is added by default.

### Built-in overlays

The files in `/boot/dtb/overlay/` are named like `rk3128-<name>.dtbo`, but in `armbianEnv.txt` you only write the `<name>` part.

Available overlays in this build are:

- `ddr3-300`
- `ddr3-330`
- `ddr3-400`
- `ddr3-600`
- `ddr3-666`
- `ddr3-700`
- `ddr3-786`
- `ddr3-800`
- `dmc-disabled`
- `emmc-enabled`
- `gpio2-sdcard-disabled`
- `sdcard-enabled`
- `uart1`
- `usb-otg-host`
- `usb-otg-peripheral`
- `wlan-esp8089`
- `wlan-rtl8189es`
- `wlan-rtl8189fs`
- `wlan-rtl8189ftv`
- `wlan-ssv6051`

### Example

This example enables `UART1`, forces OTG host mode, disables dynamic memory frequency scaling, and selects the `RTL8189FTV` Wi-Fi overlay:

```text
verbosity=1
console=ttyS1,115200
bootlogo=false
fdtfile=rk3128-linux.dtb
rootfstype=ext4
overlays=uart1 usb-otg-host dmc-disabled wlan-rtl8189ftv
extraargs=coherent_pool=2M console=tty1
```

If you want to boot from SD card and use `ESP8089`, a typical example would be:

```text
verbosity=1
console=ttyS1,115200
fdtfile=rk3128-linux.dtb
rootfstype=ext4
overlays=sdcard-enabled usb-otg-host wlan-esp8089
```

In practice, you usually only need to change `overlays`, `fdtfile`, and sometimes `extraargs` or `rootdev`. The rest can stay at their defaults.

