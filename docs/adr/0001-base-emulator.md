# ADR 0001: base emulator

Status: accepted
Date: 2026-10-21

## Context

We need an NES core that builds for ARM without SDL, is small enough for a
stripped Buildroot image, and has a PPU implementation we can replace with
hardware without rewriting the CPU.

Candidates:

| Project | License | Size | Notes |
|---|---|---|---|
| LaiNES | BSD-2-Clause | ~90 KB of source | compact, splits CPU/PPU/APU, GUI on SDL2 |
| QuickNES | GPL-2.0 | ~250 KB | very fast, designed for embedded, fewer mappers |
| FCEUX | GPL-2.0 | ~15 MB | accurate and complete, heavy, SDL-centric |

## Decision

Use **LaiNES** as the base core.

Reasons:

1. BSD-2 lets us ship the console image without licensing friction.
2. The source is small and readable: `cpu.cpp`, `ppu.cpp`, `apu.cpp`, and a
   mapper interface. The PPU is one file, which is exactly the file hardware
   rendering replaces.
3. The cycle-accurate CPU is more than fast enough on a 667 MHz A9. Speed is
   not the constraint; integration effort is.

## Consequences

- Mapper coverage is smaller than FCEUX. The ROM set we target first
  (NROM, MMC1, UxROM, CNROM, MMC3, AxROM) is supported.
- The GUI and SDL backends are removed; the core keeps only a framebuffer,
  input, and audio interface.
- If a game fails because of a mapper gap, we port that mapper, not the core.
  If we ever need more accuracy than LaiNES offers, the framebuffer API lets
  us swap in QuickNES or FCEUX behind the same interface.

## Alternatives rejected

- **QuickNES**: faster, but GPL-2 would force the whole image to GPL-2 and its
  PPU is less isolated. Kept as the fallback core.
- **FCEUX**: best compatibility, but too much code and too many host
  dependencies for a 4-second boot.
