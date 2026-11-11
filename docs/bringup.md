# Bring-up log

Reverse chronological. One entry per board session: date, bitstream or image
version, what was tested, result.

## 2026-10-23

No board attached. Console image `os/output/images/sdcard.img` (2026-10-22
12:21, UART0 fix) plus `hw/build/BOOT.BIN`.

What the last board session tells us: a test pattern on the TV means the FSBL
configured the PL from the bitstream partition in `BOOT.BIN`. It does **not**
mean U-Boot, Linux or `orbit-nes` ran: the pattern is what the PL shows until
the first DDR frame is copied and swapped in (`show_pattern = pattern_en ||
!display_ready` in `orbit_video.v`). A silent console plus a test pattern is
therefore a pre-userspace failure, not a video failure.

Checked without a board:

- Host render: `orbit-nes "roms/Legend of Zelda, The (USA) (Rev 1).nes"
  --ppm` produces the title screen (256x240, 12 colours). The core, the MMC1
  mapper and the RGB565 conversion are fine.
- `BOOT.BIN` holds three partitions: `fsbl.elf`, `orbit.bit`, `u-boot.elf`.
- U-Boot's device tree (inside `u-boot.img`) has `serial0 = uart0`
  (`/axi/serial@e0000000`), and the FSBL `ps7_init` enables UART0 on MIO 14/15,
  matching the Digilent board preset (MIO 48/49 are 1.8 V and not the bridge).
- Kernel `system.dtb` has `orbit-video@40000000` (`generic-uio`) and the
  0x1f000000 reserved frame buffer. `boot.scr` loads `uImage` and
  `system.dtb`; the U-Boot `bootcmd` sources `boot.scr` by name.
- Timing unchanged: WNS +2.325 ns, 0 failing endpoints.

Userspace no longer fails silently, so the next session can be read off the
log instead of guessed:

- `orbit_fb_open` checks the `ORB1` ID register before touching the frame
  buffer and says when the PL register block does not answer.
- `fbdemo` and `orbit-nes` print a register snapshot (`id`, `ctrl`, `status`,
  `fb`, `dma`) and a SCRATCH round-trip result at startup.
- `orbit-nes` is started with `--fb`, so a missing UIO node is an error rather
  than a null sink that leaves the pattern on screen.
- On a frame timeout the sink names the cause and exits; `S99console` logs
  which path it took, prints it to the serial console, and falls back to
  `fbdemo` if the emulator dies within a second.

Next board session, in order:

1. Capture UART0 (115200 8N1) from power-on. If there is no output at all,
   the fault is before U-Boot: recheck the FSBL partition in `BOOT.BIN`.
2. At the shell: `dmesg | grep -i uio`, `ls /dev/uio*`, `cat /var/log/console.log`.
3. `fbdemo 600` and read the printed snapshot. `id=ORB1 scratch=...` means the
   AXI-Lite path works; `no frame from the PL` with `dma=...error` points at
   the HP0 read path, and a timeout with `done=0 busy=1` at a stuck copy.

## 2026-10-21

No board connected yet.

- Bitstream and XSA build for `xc7z020clg400-1`.
- Timing met: WNS +3.460 ns, WHS +0.046 ns, 0 failing endpoints.
- Utilization: 716 LUT, 760 FF, 0 BRAM, 0 DSP. Almost all of it is the PS7
  and the AXI interconnect; the video core is a few hundred LUTs.
- Clocks: 74.21875 MHz pixel, 371.09375 MHz serial, both from the 125 MHz
  oscillator through two MMCMs.
- Next: connect a TV and confirm the test pattern.

Second bitstream adds the frame store and DDR copy engine:

- Two 256x240 RGB565 banks in BRAM, 64 RAMB36 total.
- AXI4 read master through a protocol converter into HP0.
- Scaler: 3x into the centre 768x720, nearest neighbour.
- Timing met: WNS +1.851 ns, WHS +0.035 ns, 0 critical warnings.
- Utilization: 1002 LUT, 1315 FF, 64 BRAM, 2 DSP.
- Verilator testbench copies a full frame and checks all 61,440 writes.

Third build, after the swap counter and boot path:

- Bitstream: WNS +2.325 ns, WHS +0.031 ns, 0 critical warnings.
- `orbit.bit`, `orbit.bin` and `orbit.xsa` are produced; U-Boot loads the
  raw bin with `fpga load`.
- Userspace: `fbdemo` builds; `orbit-nes` runs a synthetic NROM and writes a
  valid 256x240 PPM (host test).
- Buildroot: image built. `sdcard.img` is 257 MB (64 MB FAT boot + 192 MB
  ext4 rootfs). The boot partition has SPL, U-Boot, uImage, DTB, the raw
  bitstream and boot.scr. The rootfs has the ARM `orbit-nes` (140 KB),
  `fbdemo`, the UIO/DT nodes, and the Bluetooth/console init scripts.
- U-Boot needed a host `dd` fix for the Zynq SPL align step.
- Everything above is host-side verification.

First board session:

- SD flashed, 12 V applied, HDMI connected, UART bridge detected as an FTDI
  FT2232H (Xilinx TUL), two `ttyUSB` ports.
- No UART output, DONE LED off after power-on. The ZedBoard SPL does not
  initialize this board's DDR correctly, so the boot stops before U-Boot.
- Switched to a PYNQ-Z2 FSBL generated from `orbit.xsa`: `BOOT.BIN` is FSBL +
  bitstream + U-Boot (5.2 MB), and the FSBL programs the PL. The boot script
  no longer loads the bitstream.
- Image rebuilt with the new boot partition; awaiting reflash.
