# console userspace

Two small programs and the register header that ties Linux to the PL:

- `fbdemo` draws an animated 256x240 plasma, commits it to the reserved DDR
  frame buffer and waits for the PL to display it. It is the first thing to
  run on the board.
- `tests/test_convert` checks the RGB565 helpers on the host.

## How the handoff works

1. The device tree reserves 120 KiB at `0x1F000000` and exposes the PL
   registers at `0x40000000` through UIO.
2. `fbdemo` maps both, clears `CTRL` to leave test-pattern mode and sets
   `FB_ADDR`.
3. Each frame it packs two RGB565 pixels per 32-bit store, then writes `1` to
   `DMA_CTRL`.
4. The PL copies the DDR buffer into the off-screen BRAM bank and swaps banks
   at the next frame start. `STATUS[31:16]` counts displayed frames.

The DDR mapping is uncached (`/dev/mem`, no-map region). One frame is 30,720
32-bit stores, a few milliseconds on a 667 MHz A9, and only once per frame.

## Build

```bash
make            # fbdemo
make check      # host tests
```

The Buildroot package cross-compiles the same Makefile with the Buildroot
toolchain.

## Run

```bash
fbdemo          # until Ctrl-C
fbdemo 600      # ten seconds at 60 Hz
```

If it prints `no frame from the PL`, the bitstream is not loaded or the UIO
node is missing. See `docs/bringup.md`.

## Register map

`include/orbit/fb.h` is the C copy of the map in `docs/architecture.md`. Keep
all three in sync: the RTL, the doc, and this header.
