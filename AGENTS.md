# AGENTS.md

Guide for AI coding agents working on this repository. Read it before
changing anything.

## Mission

Turn a PYNQ-Z2 into a standalone NES console:

- ARM runs the guest CPU, mappers, APU, and menus.
- FPGA runs the PPU, scaler, and HDMI transmitter.
- Buildroot Linux boots straight into the emulator.
- 8BitDo controller over Bluetooth, ROMs on SD, HDMI to the TV.

`docs/architecture.md` is the source of truth. If a change alters behavior,
the doc changes in the same PR.

## Layout

```
hw/rtl/          synthesizable Verilog
hw/sim/          Verilator testbenches
hw/constraints/  XDC
hw/scripts/      Vivado build and packaging TCL
hw/ip/           generated IP (not committed)
sw/nes/          LaiNES fork (BSD-2, vendored)
sw/console/      headless console front end: input, audio, frame pacing
os/              Buildroot defconfig, rootfs overlay, kernel fragment
scripts/         host helpers
docs/            architecture, roadmap, ADRs, bring-up log
```

## Golden rules

1. **Do not guess hardware.** Check the Digilent board files before assigning
   a pin: `/tools/Xilinx/2025.2/Vivado/data/boards/board_files/pynq-z2/A.0/`.
2. **Close timing.** A bitstream with negative WNS is a failed change.
3. **Keep the framebuffer contract stable.** Software and hardware both write
   RGB565 with stride 512 into the same 256x240 buffer. Changes to the format
   update both sides and the docs.
4. **No SDL, no X, no Python on the target.** The image is stripped on purpose.
5. **Do not modify vendored code outside `sw/nes/vendor`** unless the patch is
   recorded in `THIRD_PARTY.md` and kept as a small patch file.
6. **Never commit build output or bitstreams.** Releases attach them.
7. **Ask on ambiguity.** A wrong PPU flag is a debugging week; a question is a
   minute.

## Commands

```bash
make lint            # Verilator lint over hw/rtl
make sim             # Verilator unit testbenches
make hw              # Vivado: synth, impl, bitstream, XSA
make sw              # cross-build the console
make os              # Buildroot image
```

Vivado is not on PATH by default:

```bash
source /tools/Xilinx/2025.2/settings64.sh
```

The Vivado MCP server can also drive it, which is how this repo is normally
built. Use `vivado_start` with `session_type=ipi` and the repo root as the
working directory.

## Register map discipline

Any change to `0x4000_0000` offsets updates:

- `hw/rtl/video_regs.v`
- `docs/architecture.md` section 5
- the Linux UIO userspace header `sw/console/orbit_regs.h`

All three in the same PR.

## Verification expectations

- New RTL: a testbench in `hw/sim`, added to the Makefile, passing.
- New board-level behavior: a note in `docs/bringup.md` with date and result.
- New software path: at least a host-side test or a hardware log.
