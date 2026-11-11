# Linux image

Buildroot external tree for a stripped PYNQ-Z2 console image:

- Linux 6.12 LTS with a PYNQ-Z2 device tree (ZedBoard peripherals plus a
  reserved frame buffer and a UIO node for the video registers).
- U-Boot proper, loaded by the FSBL. The SPL build is still enabled in the
  defconfig but nothing flashes or runs it.
- BusyBox, BlueZ, ALSA, libevdev, and the `orbit-console` package.
- No X, no Python, no systemd.

## Build

```bash
make hw                 # from the repo root: bitstream + XSA
os/scripts/build_boot_bin.sh   # FSBL + bitstream + U-Boot -> hw/build/BOOT.BIN
make os                 # Buildroot: output/images/sdcard.img
```

The first `make os` downloads Buildroot 2026.02.3 and about 1 GB of sources.
`BOOT.BIN` must exist before `make os`; the post-build step builds it if it is
missing.

Write the image to an SD card:

```bash
sudo dd if=os/output/images/sdcard.img of=/dev/sdX bs=4M status=progress conv=fsync
```

## Boot

1. Put the SD card in, set the boot jumper to SD, connect UART and HDMI.
2. Power on. The FSBL inside `BOOT.BIN` configures the PL from the bitstream
   partition, then starts U-Boot. U-Boot loads the kernel and DTB.
3. `S99console` starts `orbit-nes --fb` with the first `/roms/*.nes`, or
   `fbdemo` if there is no ROM or the emulator dies. Both write to
   `/var/log/console.log`, and the stage lines also appear on UART0.

A test pattern on HDMI only means step 2 happened: the PL shows it until the
first DDR frame is swapped in.

`BOOT.BIN` is FSBL + bitstream + U-Boot, built from the XSA by
`os/scripts/build_boot_bin.sh`. It uses the PYNQ-Z2 `ps7_init` (DDR, clocks,
MIO), not the ZedBoard SPL. The post-build step runs the script if
`hw/build/BOOT.BIN` is missing; Vitis (`xsct`, `bootgen`) must be installed.

Serial console: `ttyPS0`, 115200 8N1.

## ROMs

The image builds and installs **Nova the Squirrel** from the submodule at
`third_party/NovaTheSquirrel`.

For anything else, put `.nes` files in the repo's `roms/` directory before
`make os`; it is gitignored and copied into `/roms`. The console boots the
first file alphabetically, so name the one you want first, for example
`legend-of-zelda.nes`.

Commercial ROMs are not part of this repository. Dump and use your own
cartridges; do not commit them.

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

- **FSBL DDR init.** The FSBL comes from our XSA, so the DDR settings match
  the PYNQ-Z2. It enables UART0 on MIO 14/15, as the Digilent preset does. If
  the board is still silent, check that `BOOT.BIN` is the one built by
  `os/scripts/build_boot_bin.sh`.
- **PS to PL video handoff.** Never confirmed on hardware. Reflash and read
  `/var/log/console.log`; `docs/bringup.md` lists the exact checks.
- **USB PHY.** The device tree uses the ZedBoard-style `usb-nop-xceiv` node.
  PYNQ-Z2 has a ULPI PHY; if the dongle is not detected, switch to the
  `ulpi-phy` node from TUL's reference tree.
- **Bluetooth pairing UX.** Pairing is a manual one-time step. Auto-discovery
  is deliberately not enabled.
- **Audio.** The ADAU1761 is enabled in the kernel but the APU still runs in
  software; there is no audio path wired to the codec yet.
