# Project Emulator

A standalone retro console built on the PYNQ-Z2 (Zynq-7020), with the work split
the way the original hardware split it:

- **ARM (PS)** runs the guest CPU, mappers, and game logic.
- **FPGA (PL)** runs the PPU, the scaler, and the HDMI transmitter.

The result is a cartridge-less NES-class console: SD card for ROMs, Bluetooth
8BitDo controller over a USB dongle, HDMI to the TV, and a stripped Linux image
that boots straight into the emulator.

Status: the video pipeline, framebuffer path, userspace and headless
emulator are built and tested on the host. The Linux image is configured and
building. Nothing has run on a board yet; see
[`docs/bringup.md`](docs/bringup.md) for exactly what was verified.

## AI disclosure

This project is vibe-coded: nearly all of the code, RTL, build scripts and
documentation were written by AI coding agents, with a human directing the
work, reviewing results and running the tools. It is also an experiment to
find where AI assistance falls short in RTL design, such as timing closure,
hardware-accurate behavior and board bring-up. Expect rough edges, and treat
nothing as verified unless [`docs/bringup.md`](docs/bringup.md) says it ran on
real hardware.

## Repository layout

```
docs/          architecture, roadmap, decisions, board notes
hw/            RTL, simulation, constraints, Vivado build scripts
sw/            emulator core, userland tools
os/            Buildroot defconfig and rootfs overlay
scripts/       host-side helpers
```

## Build

```bash
git clone --recurse-submodules <repo>
make hw        # Vivado: bitstream + XSA
make os        # Buildroot: SD image
make sw        # emulator for ARM
```

## Games

The image ships **Nova the Squirrel**, built from the
[upstream source](https://github.com/NovaSquirrel/NovaTheSquirrel) that is
pinned as a submodule in `third_party/`. Code is GPLv3, assets are
CC BY-NC-SA 4.0; see `THIRD_PARTY.md`.

Your own ROMs go in `roms/`, which is gitignored. `make os` copies them into
the image and the console boots the first one alphabetically. Do not commit
commercial ROMs; dumping and using them is your responsibility.

## License

Original code in this repository is MIT licensed. Vendored third-party code
keeps its own license; see [`THIRD_PARTY.md`](THIRD_PARTY.md).
