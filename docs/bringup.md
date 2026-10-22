# Bring-up log

Reverse chronological. One entry per board session: date, bitstream or image
version, what was tested, result.

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
- Buildroot: toolchain, kernel, rootfs and U-Boot build; the image assembly
  is running. U-Boot needed a host `dd` fix for the Zynq SPL align step.
