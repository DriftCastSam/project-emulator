# sw/nes — headless LaiNES core

A SDL-free build of [LaiNES](https://github.com/AndreaOrru/LaiNES) for the
console. It runs the 6502, mappers, PPU and APU in software and hands finished
frames to a small `FrameSink`. No SDL, no X, no window, no audio device.

This is the compatibility path described in `docs/architecture.md` section 7:
the same emulator keeps working while the PPU and video path move to the PL.

## Layout

```
include/gui.hpp        headless GUI API the core links against
src/gui.cpp            frame conversion (0x00RRGGBB -> RGB565) and stubs
src/frame_sink.h       FrameSink, NullSink, PpmSink
src/frame_sink.cpp     PPM writer with optional integer scaling
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
  controller 0 reads as all buttons released, fast-forward is always false.
- `src/frame_sink.*` decouples the frontend from the video backend. `PpmSink`
  writes a binary PPM; `NullSink` drops frames.
- `src/main.cpp` implements the `orbit-nes` command line.

The frame contract matches the hardware path: 256x240 RGB565, 512 bytes per
row. A DDR framebuffer sink can be added behind `FrameSink` without touching
the emulator.

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
```

- `--frames N` run N frames (default 60)
- `--ppm FILE` write the last frame as a binary PPM (P6, 8-bit RGB)
- `--scale N` integer nearest-neighbour upscale for the PPM (default 1)

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

- **Input**: `get_joypad_state` always returns 0. The evdev backend (8BitDo over
  Bluetooth, USB keyboard fallback) still has to feed a controller byte.
- **Audio**: `new_samples` is a no-op. ALSA output and the sample queue are not
  implemented; the APU runs but its samples are dropped.
- **Video sink**: only PPM and null sinks exist. The DDR framebuffer sink
  (`/dev/uio`, register map `0x4000_0000`, `FB_ADDR`/`DMA_CTRL`) is not written.
- **Hardware PPU**: the software PPU is the only renderer. The `--ppu=hw`
  backend and the register mirror are not implemented.
- **Pacing**: the frame loop runs as fast as the host allows. There is no
  vsync or wall-clock limiter, which is fine for tests but wrong for a console.
- **Frontend extras**: save states, menus, ROM selection and fast-forward are
  not exposed by the CLI. `SaveState::save/load` exists in the core but is not
  wired up.
