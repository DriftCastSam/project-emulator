# Architecture

Status: draft, reviewed before any RTL is merged.

## 1. Target

A standalone NES-class console on a PYNQ-Z2:

| Piece | Choice |
|---|---|
| Board | PYNQ-Z2, XC7Z020-1CLG400C, 512 MB DDR3 |
| Display | HDMI out, 1280x720p60, 3x integer scale of 256x240 |
| Audio | on-board ADAU1761 line out (phase 6), HDMI audio later |
| Input | 8BitDo over Bluetooth, USB dongle on the PS USB host port |
| Storage | microSD: boot partition + rootfs + `/roms` |
| OS | Buildroot, Linux 6.12 LTS, BusyBox, BlueZ, ALSA |
| Emulator | LaiNES (BSD-2) fork, headless, no SDL |

The console is not a Linux desktop. It boots in a few seconds, starts one
process, and that process owns the display and the controller.

## 2. Why split CPU and PPU across ARM and FPGA

The real NES has two chips: a 2A03 (6502 + APU) and a 2C02 (PPU). This project
keeps that split:

- The **PS** is good at control flow: the 6502 interpreter, mappers, menus, the
  Bluetooth stack. A 667 MHz Cortex-A9 has roughly 370 host cycles per guest
  cycle, which is plenty for a 1.79 MHz CPU.
- The **PL** is good at fixed-function work: tile fetch, sprite priority,
  pixel composition, scaling, and TMDS serialization. These are cheap in
  gates and have hard real-time deadlines.
- Moving the PPU to the PL is also what makes the video path console-like:
  the frame is produced in step with the display instead of being copied
  around by the CPU.

Software rendering is kept as a compatibility path. The hardware PPU starts
with backgrounds, then sprites, then the status flags. Until a feature is
implemented in RTL, the emulator's software renderer fills the same
framebuffer, so the console is always usable.

## 3. Block diagram

```
                  +------------------------------------------+
   microSD  <---->|  PS: 2x Cortex-A9 @ 667 MHz, 512 MB DDR3 |
   USB/BT   <---->|                                          |
   UART     <---->|  orbit-console (LaiNES fork)             |
                  |    CPU / mappers / APU / menus           |
                  +----+----------------------+--------------+
                       | M_AXI_GP0            | HP0 (64-bit)
                       | AXI-Lite 0x4000_0000 | DDR reads
                       v                      v
                  +------------------------------------------+
                  |  PL                                      |
                  |  PPU regs + CHR/NT/OAM/palette BRAM      |
                  |  256x240 RGB565 framebuffer BRAM         |
                  |  DMA: DDR framebuffer -> BRAM            |
                  |  3x scaler (768x720, centered)           |
                  |  TMDS encode + serialize (3 lanes)       |
                  +----------------------+-------------------+
                                         |
                                      HDMI out
```

## 4. Video path

### 4.1 Timing

1280x720p60, CEA-861:

| Parameter | Value |
|---|---|
| Pixel clock | 74.25 MHz (generated: 74.21875 MHz) |
| H total / active / FP / sync / BP | 1650 / 1280 / 110 / 40 / 220 |
| V total / active / FP / sync / BP | 750 / 720 / 5 / 5 / 20 |
| TMDS serial clock | 5x pixel = 371.09375 MHz DDR |

The 0.04% pixel clock error is inside the +/-0.5% DVI/HDMI tolerance. Fallback
if the 371 MHz serializer fails timing on the -1 part is 640x480p60 (25.175
MHz pixel, 125.875 MHz serial) with 2x scale. The scaler and timing generator
are parameterized so the fallback is a config change, not a rewrite.

### 4.2 Scaling

NES output is 256x240. At 3x it becomes 768x720, centered horizontally with a
256 pixel black border on each side. Vertical is exact, so no letterbox.

### 4.3 Framebuffer

Two 256x240 RGB565 banks live in BRAM (about 60 BRAM36 total), dual clocked:

- write side: DDR copy engine, later the hardware PPU
- read side: pixel clock, 3x nearest-neighbor

The copy engine is a read-only AXI4 master on HP0. It pulls 120 KiB with
64-bit bursts and unpacks one pixel per clock, about 0.8 ms per frame. It
always writes the bank that is not on screen; the display swaps banks at the
next frame start, so there is no tearing. The swap count in `DMA_STATUS` lets
userspace know when the DDR buffer is free again, which is also the frame
pacing.

Two producers can fill a bank:

1. **Hardware PPU** renders directly into it (M5).
2. **Software PPU** renders into a reserved DDR region, then triggers the
   copy engine.

A test pattern generator (colour bars, moving box, grey ramp) can be selected
instead, so HDMI can be brought up before any emulator exists.

### 4.4 TMDS

Three 8b/10b encoders plus a 10:1 DDR serializer built on OSERDESE2, and a
clock lane serialized as `1111100000` to forward the pixel clock. Output is
DVI-compatible TMDS; HDMI infoframes and audio are phase 6.

## 5. Memory map

PS (Zynq):

| Region | Address | Notes |
|---|---|---|
| DDR | 0x0000_0000 | 512 MB |
| AXI GP0 | 0x4000_0000 | PL registers (UIO) |
| DDR framebuffer | 0x1F00_0000 | 1 MB `reserved-memory`, uncached |
| DDR PPU trace | 0x1F10_0000 | optional debug ring |

PL AXI-Lite register map, 4 KiB:

| Offset | Name | Description |
|---|---|---|
| 0x000 | ID | "ORB1" |
| 0x004 | CTRL | [0] test pattern, [1] animate |
| 0x008 | STATUS | [0] locked, [1] vsync, [2] frame ready, [31:16] frame count |
| 0x00C | FB_ADDR | DDR physical address of the software framebuffer |
| 0x010 | FB_STRIDE | bytes per line (512) |
| 0x014 | DMA_CTRL | [0] start copy (latches FB_ADDR) |
| 0x018 | DMA_STATUS | [0] busy, [1] done, [2] error, [31:16] swap count |
| 0x01C | SCRATCH | read/write test register |
| 0x100+ | PPU | PPU register mirror (phase 5) |

## 6. Hardware PPU

The PPU is exposed to the emulator through the same registers a 2C02 has, so
the software side changes as little as possible.

### 6.1 Memories

| Memory | Size | Access |
|---|---|---|
| Pattern tables (CHR) | 8 KiB | PS writes, PPU reads 2 tiles/cycle |
| Nametables | 2 KiB | PS writes, PPU reads |
| Palette | 32 B | PS writes, PPU reads |
| OAM | 256 B | PS writes via OAM DMA port |
| Framebuffer | 120 KiB | PPU writes, scanout reads |

### 6.2 Register model

PS writes go into a small command FIFO with a dot timestamp. The PPU applies
each write at its timestamp, which preserves mid-scanline effects such as
split-screen scrolling. Reads of `$2002` return flags sampled at the read
timestamp.

Phase 5a ignores timestamps and works at scanline granularity. That is enough
for most games and much simpler to verify. Phase 5c turns on the timestamped
path (see `docs/roadmap.md`).

**Scanline-granularity contract (5a).** The renderer draws one visible line
from a snapshot of the line state, taken at dot 320 of the previous line, before
the two prefetch tiles. Register writes made after dot 257 of a line and before
dot 320 are therefore seen by the next line, and writes made during the visible
part of a line are not seen until a later one. The snapshot is:

| Field | Source |
|---|---|
| V (15 bits) | loopy V after the dot-257 horizontal copy, including the vertical copy on the pre-render line |
| fine X | `$2005` first write |
| bg pattern table | PPUCTRL bit 4 |
| bg on, bg left column, gray | PPUMASK bits 3, 1, 0 |

V is the raw loopy register `[14:12]` fine Y, `[11:10]` nametable, `[9:5]`
coarse Y, `[4:0]` coarse X. Software drives the snapshot until the loopy
register logic (`$2000`, `$2005`, `$2006`) moves into the PL; that unit is the
next slice and is verified against `PPU::get_state` line by line.

Not covered by 5a: mid-line mask or scroll changes, emphasis bits, sprites,
four-screen mirroring (needs 4 KiB of nametable RAM), CHR bank switching
during a frame (MMC3 and similar; needs a decision on whether the PS rewrites
CHR or the PL gets bank registers), and reads or writes through `$2007`.

### 6.3 Rendering

Implemented in `hw/rtl` as `ppu_render` (top), `ppu_bg` (fetch and pixel
generation), `ppu_mem` (CHR RAM, nametable RAM, mirroring) and `ppu_pal`
(palette RAM, aliasing, grayscale, RGB565 lookup through the generated
`nes_pal_rom`). The 5a background renderer is tile-at-a-time, not dot-accurate:
per tile it reads the nametable byte, attribute byte and two pattern bytes
through one-cycle-latency ports, then emits 8 pixels; 33 tiles per line cover
any fine X. A line takes 561 cycles, far inside the 5000 available at
74.25 MHz, so it needs no overlap between fetch and output. Output is RGB565,
matching the framebuffer contract (section 4.3). Mirroring: 0 vertical,
1 horizontal, 2 one-screen upper, 3 one-screen lower.


Per scanline:

1. Fetch 33 background tiles from the nametable, 2 bits per pixel.
2. Fetch up to 8 sprites, sorted by OAM order, 8 pixels wide.
3. Compose: background first, sprites by priority, sprite 0 hit detection.
4. Convert through the palette to RGB565 and write to the framebuffer.

Fine X scroll shifts the background pipeline by 0..7 pixels. Y scroll selects
the nametable row. Mirroring is set by the mapper through a register.

### 6.4 Status flags

Vblank, sprite 0 hit, and sprite overflow are generated in hardware at the
correct dot. The emulator reads them instead of estimating them. This is the
part that most affects compatibility, so it gets a dedicated test suite.

### 6.5 What stays in software

- CPU and all mappers
- APU (phase 6 moves it to hardware)
- Game loading, menus, save states
- Cheats, rewinds

## 7. Software stack

### 7.1 Emulator

LaiNES is vendored in `sw/nes` (BSD-2). It is small, splits CPU/PPU/APU, and
its PPU is easy to replace. Modifications:

- headless core API, no SDL, no GUI
- video backend (`FbSink`) writes RGB565 through UIO and the reserved
  framebuffer, and blocks on the display swap. It checks the `ORB1` ID register
  before the first frame, prints a register snapshot at startup, and stops the
  console with the reason if the PL stops answering.
- input backend (`Input`) reads evdev, scans for a gamepad, and maps 8BitDo
  XInput buttons and hat/sticks to the NES shift-register byte
- audio backend writes ALSA (phase 4)
- optional hardware PPU backend behind `--ppu=hw`

### 7.2 Linux image

Buildroot with:

- Linux 6.12 LTS, PYNQ-Z2 device tree from mainline plus reserved-memory and
  UIO nodes
- BusyBox init, no systemd, no X, no Python
- BlueZ with the HID host plugin, `btusb`, `hid-generic`, `evdev`
- ALSA lib + ADAU1761 codec driver
- one local package: `orbit-console`

Target image size: under 64 MB, boot under 8 seconds.

### 7.3 Boot

```
BOOT.BIN (FSBL + bitstream + U-Boot)
  -> zImage + zynq-pynq-z2.dtb from FAT partition
  -> rootfs (ext4 or squashfs) from second partition
  -> /etc/init.d/S99console starts orbit-console
```

## 8. Performance budget

| Item | Budget | Notes |
|---|---|---|
| Guest CPU | 1.79 MHz | ~10x headroom on one A9 |
| Pixels | 3.7 Mpx/s | trivial in PL |
| DDR framebuffer traffic | 7.4 MB/s | one 120 KiB copy per frame |
| Boot | < 8 s | kernel + BusyBox + emulator |
| Input latency | < 50 ms | BT + evdev + one frame |

## 9. Verification

- **Verilator**: lint plus unit testbenches for timing generator, TMDS
  encoder, scaler, and PPU pixel pipeline. Runs in CI.
- **PPU golden vectors**: `sw/nes/test/ppu_golden.cpp` drives the vendored
  LaiNES PPU with no CPU, over seeded random memories and per-line register
  writes, and records the line state and every output pixel. `tb_ppu_render`
  replays the same memories and line state into the RTL and compares all
  61,440 pixels per scenario. Eight scenarios cover all four mirroring modes,
  scroll and nametable changes, coarse X wrap, mask toggles and palette
  aliasing. The reference is LaiNES, not a real 2C02, so a bug LaiNES shares
  with the RTL is not caught; compatibility ROMs on hardware are the check
  for that.
- **Vivado xsim**: anything that instantiates OSERDESE2 or MMCM.
- **Vivado**: synthesis, implementation, timing report. WNS must be positive
  at 74.21875 MHz and 371.09375 MHz.
- **Hardware**: test pattern, DDR framebuffer gradient, NES ROM, controller
  latency. Logged in `docs/bringup.md` as it happens.

## 10. Risks and fallbacks

| Risk | Fallback |
|---|---|
| 371 MHz OSERDES on -1 part | 640x480p60, 2x scale |
| HDMI 3.3V TMDS drive | Digilent rgb2dvi reference design |
| Mid-scanline PPU writes | scanline-granularity first, timestamped later |
| 8BitDo pairing UX | auto-pair service with saved MAC, USB cable fallback |
| LaiNES mapper coverage | swap core behind the same framebuffer API |
| DDR coherency | uncached reserved region first, DMA driver later |

## 11. Decisions

- [ADR 0001: base emulator](adr/0001-base-emulator.md)
