# Linux image

Buildroot external tree for a stripped PYNQ-Z2 console image:

- Linux 6.12 LTS with a PYNQ-Z2 device tree (ZedBoard peripherals plus a
  reserved frame buffer and a UIO node for the video registers).
- U-Boot with SPL, booting `boot.scr` from the FAT partition and loading the
  bitstream before Linux.
- BusyBox, BlueZ, ALSA, libevdev, and the `orbit-console` package.
- No X, no Python, no systemd.

## Build

```bash
make hw                 # from the repo root: bitstream + XSA
make os                 # Buildroot: output/images/sdcard.img
```

The first `make os` downloads Buildroot 2026.02.3 and about 1 GB of sources.
The bitstream is taken from
`hw/build/vivado/orbit.runs/impl_1/system_wrapper.bin`; set `ORBIT_BITSTREAM`
to override it.

Write the image to an SD card:

```bash
sudo dd if=os/output/images/sdcard.img of=/dev/sdX bs=4M status=progress conv=fsync
```

## Boot

1. Put the SD card in, set the boot jumper to SD, connect UART and HDMI.
2. Power on. U-Boot loads the bitstream, then the kernel.
3. The console starts `orbit-nes` with the first `/roms/*.nes`, or `fbdemo`
   if there is no ROM.

Serial console: `ttyPS0`, 115200 8N1.

## ROMs and controller

Copy ROMs to `/roms` on the rootfs partition (mount it on a Linux host, or
use `scp` once the network is up).

Pair an 8BitDo once:

```sh
# Put the controller in XInput mode: hold Start + X until the LED blinks.
bluetoothctl scan on          # find the MAC
orbit-bt-pair AA:BB:CC:DD:EE:FF
```

`S45orbit-bt` reconnects the saved MAC on every boot. The controller shows up
as `/dev/input/event*`; the emulator reads evdev directly.

## Known unknowns

These are the parts that need a board to confirm:

- **SPL DDR init.** U-Boot uses the `zynq_zed` board configuration. PYNQ-Z2
  and ZedBoard both have 512 MB of 32-bit DDR3, but if the board does not
  boot, the DDR settings in `board/xilinx/zynq/` are the first thing to check.
- **USB PHY.** The device tree uses the ZedBoard-style `usb-nop-xceiv` node.
  PYNQ-Z2 has a ULPI PHY; if the dongle is not detected, switch to the
  `ulpi-phy` node from TUL's reference tree.
- **Bluetooth pairing UX.** Pairing is a manual one-time step. Auto-discovery
  is deliberately not enabled.
- **Audio.** The ADAU1761 is enabled in the kernel but the APU still runs in
  software; there is no audio path wired to the codec yet.
