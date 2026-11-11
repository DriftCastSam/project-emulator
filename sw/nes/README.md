# sw/nes — headless LaiNES core

A SDL-free build of [LaiNES](https://github.com/AndreaOrru/LaiNES) for the
console. It runs the 6502, mappers, PPU and APU in software and hands finished
frames to a small `FrameSink`. No SDL, no X, no window, no audio device.

This is the compatibility path described in `docs/architecture.md` section 7:
the same emulator keeps working while the PPU and video path move to the PL.

## Layout

```
include/gui.hpp        headless GUI API the core links against
src/gui.cpp            frame conversion (0x00RRGGBB -> RGB565) and APU stub
src/frame_sink.h       FrameSink, NullSink, PpmSink
src/frame_sink.cpp     PPM writer with optional integer scaling
src/fb_sink.h/.cpp     DDR framebuffer sink (/dev/uio0 + reserved memory)
src/input.h/.cpp       evdev gamepad thread, 8BitDo XInput mapping
src/main.cpp           orbit-nes command line frontend
test/make_test_rom.py  builds a tiny synthetic NROM cartridge
test/check_ppm.py      validates the PPM and counts colours
vendor/laines/         upstream sources, unmodified
```

## Vendored code

LaiNES is vendored at commit `1f3d126171104ec57e515641ea3b5291d383ebdf`
(2025-11-05), BSD-2-Clause. See `vendor/laines/UPSTREAM.md` for the exact file
list and `vendor/laines/LICENSE` for the license.

The copied `.cpp` and `.hpp` files are byte-identical to upstream. The SDL GUI,
menus, settings and the SDL `Sound_Queue` are not copied. Nothing under
`vendor/` is patched.

## Local modifications

All changes are outside `vendor/`:

- `include/gui.hpp` replaces the SDL header. It keeps the four symbols the core
  uses (`new_frame`, `new_samples`, `get_joypad_state`, `is_fast_forward`) and
  adds `frame_rgb565()`, `frame_ready()` and `clear_frame_ready()`.
- `src/gui.cpp` converts the PPU's 256x240 `u32` frame (stored as `0x00RRGGBB`)
  to RGB565 and sets the frame-ready flag. Audio samples are discarded,
  fast-forward is always false, and controller 0 comes from the evdev thread.
- `src/frame_sink.*` decouples the frontend from the video backend. `PpmSink`
  writes a binary PPM; `NullSink` drops frames; `FbSink` sends frames to the PL
  and blocks on the display swap.
- `src/input.*` finds a gamepad under `/dev/input`, reads it on a thread and
  publishes the NES button byte.
- `src/main.cpp` implements the `orbit-nes` command line.

The frame contract matches the hardware path: 256x240 RGB565, 512 bytes per
row.

## Build

Needs `g++` with C++14 and `python3` for the test ROM. No SDL.

```sh
make            # builds build/orbit-nes
make test       # builds the test ROM, renders 3 frames, checks the PPM
make clean
```

## Run

```
orbit-nes <rom.nes> [--frames N] [--ppm out.ppm] [--scale N]
          [--input PATH] [--fb] [--null]
```

- `--frames N` run N frames (0 or unset with the DDR sink: forever)
- `--ppm FILE` write the last frame as a binary PPM (P6, 8-bit RGB)
- `--scale N` integer nearest-neighbour upscale for the PPM (default 1)
- `--input PATH` evdev device (default: scan `/dev/input`)
- `--fb` require the PL framebuffer; fail instead of falling back to no video
- `--null` run without a video backend

```sh
build/orbit-nes roms/game.nes --frames 120 --ppm frame.ppm --scale 2
```

A ROM that cannot be opened or uses an unsupported mapper prints an error and
exits with status 1.

## Test

`make test` writes `build/test.nes` with `test/make_test_rom.py`: a 16 KiB PRG,
8 KiB CHR NROM (mapper 0, vertical mirroring). The PRG waits out the PPU warmup,
writes a palette and fills nametable 0 with tile 0, enables the background and
spins. Tile 0 is a 4-pixel stripe pattern, so the frame is blue and black
vertical stripes.

The test then runs `orbit-nes` for 3 frames, writes `build/test.ppm`, and
`test/check_ppm.py` verifies the P6 header, 256x240x8-bit dimensions and at
least two distinct pixel values. It prints the PPM path and the colour count.

## Missing pieces

- **Audio**: `new_samples` is a no-op. ALSA output and the sample queue are not
  implemented; the APU runs but its samples are dropped. This is milestone 6
  in `docs/roadmap.md`, and it needs the PL I2S path to the ADAU1761.
- **Framebuffer sink**: implemented (`src/fb_sink.cpp`), but never confirmed on
  a board; the handoff is instrumented and documented in `docs/bringup.md`.
- **Hardware PPU**: the software PPU is the only renderer. The `--ppu=hw`
  backend and the register mirror are not implemented.
- **Pacing**: the DDR sink blocks on the PL frame swap, which paces the
  emulator. The PPM and null sinks run as fast as the host allows, which is
  fine for tests.
- **Frontend extras**: save states, menus, ROM selection and fast-forward are
  not exposed by the CLI. `SaveState::save/load` exists in the core but is not
  wired up.
