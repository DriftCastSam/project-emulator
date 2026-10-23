# Roadmap

Each milestone is a mergeable slice with an acceptance test. Hardware
milestones are not done until the bitstream closes timing; software milestones
are not done until they run on the board.

Status: M0-M2 are done and verified on the host. M3-M4 are implemented and
configured but not yet run on a board. On the board, M1 is confirmed (the test
pattern shows); the rest of the video path is not.

## M0: foundation

- Repo layout, contributing rules, architecture, ADRs.
- CI: Verilator lint, host build of the emulator core.

Acceptance: `make lint` and `make sw` pass on a clean checkout.

## M1: HDMI bring-up

- PS7 + AXI interconnect + video register block.
- Clocking: 74.21875 MHz pixel, 371.09375 MHz serial.
- TMDS encoder, serializer, test pattern.
- Constraints for the PYNQ-Z2 HDMI pins.

Acceptance: bitstream builds, timing closes, test pattern shows on a TV.

## M2: framebuffer path

- 256x240 RGB565 BRAM framebuffer.
- AXI master copy from DDR, triggered per frame.
- 3x scaler, 768x720 centered.
- Linux-side test tool that draws a gradient and a moving box.

Acceptance: tear-free gradient and motion at 60 fps.

## M3: Linux image

- Buildroot defconfig for PYNQ-Z2.
- Kernel with USB, BT, HID, evdev, ALSA, UIO.
- UIO node for the video registers, reserved-memory node for the framebuffer.
- BusyBox init, BlueZ auto-pair service.

Acceptance: board boots to a shell over UART in under 8 s; 8BitDo pairs and
shows up as `/dev/input/event*`.

## M4: software-rendered NES

- LaiNES fork builds for ARM, no SDL.
- ROM from SD, evdev input, framebuffer output.
- Frame pacing at 60 Hz.

Acceptance: Super Mario Bros. and Zelda run at full speed with working audio
(ALSA) and controller.

## M5: hardware PPU

- 5a: CHR/NT/OAM/palette BRAM, background rendering, palette, scroll,
  mirroring, scanline-granularity register writes.
- 5b: sprites, priority, sprite 0 hit, overflow, vblank timing.
- 5c: dot-timestamped register writes.

Acceptance: each stage passes the PPU unit tests and a compatibility ROM
suite; 5c passes games known for mid-frame effects.

## M6: console polish

- APU in hardware and I2S out through the ADAU1761.
- On-screen menu, ROM browser, save states.
- HDMI audio (optional).

## M7: stretch

- Second core (Game Boy, then Genesis). The video path is shared; only the
  core and its tile format change.
- SNES is explicitly out of scope until the NES path is solid. A software
  SNES core can use the same framebuffer and scaler if the A9 is fast enough.
