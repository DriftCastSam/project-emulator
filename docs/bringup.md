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
