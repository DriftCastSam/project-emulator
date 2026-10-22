# Upstream

Vendored LaiNES sources used by the headless NES core.

| Field | Value |
|---|---|
| Project | LaiNES |
| Repository | https://github.com/AndreaOrru/LaiNES |
| Commit | `1f3d126171104ec57e515641ea3b5291d383ebdf` |
| Commit date | 2025-11-05 |
| License | BSD-2-Clause, Copyright (c) 2020 Andrea Orru, see `LICENSE` |

## What is copied

- `src/{apu,cartridge,cpu,mapper,ppu,joypad,savestate}.cpp`
- `src/mappers/*.cpp`
- `src/include/{apu,cartridge,common,cpu,joypad,mapper,ppu,savestate}.hpp`
- `src/include/mappers/*.hpp`
- `src/palette.inc`
- `lib/*.cpp` and `lib/include/**` (blargg's APU, Blip_Buffer and Nes_Apu)

## What is left out

- `src/gui.cpp`, `src/menu.cpp`, `src/config.cpp`, `src/main.cpp` and their
  headers: SDL2 GUI, menus and settings.
- `lib/Sound_Queue.cpp`, `lib/include/Sound_Queue.h`: an SDL2 audio queue that
  the APU does not use.
- `res/`, `SConstruct`, `README.md` and the upstream `.gitmodules`: not needed
  for the headless build.

## Local modifications

None. The copied files are byte-identical to the upstream commit. The headless
GUI lives outside this directory in `sw/nes/include/gui.hpp` and
`sw/nes/src/gui.cpp`, so the core links against it without patching vendored
code.
