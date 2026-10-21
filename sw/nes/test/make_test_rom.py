#!/usr/bin/env python3
"""Generate the synthetic NROM cartridge used by `make test`.

The ROM is the smallest thing that proves the emulator renders: it waits out
the PPU warmup, fills nametable 0 with tile 0, loads a palette where colour 3
is light blue and colour 0 is black, enables the background, waits for one
vblank so a complete steady-state frame is rendered, then spins.

CHR tile 0 has both bit planes set to 0xF0, so the left half of every tile is
palette colour 3 and the right half is the backdrop colour 0. The frame is
therefore vertical stripes, which gives the checker at least two colours.
"""

import struct
import sys

PRG_BASE = 0x8000
PRG_SIZE = 16 * 1024
CHR_SIZE = 8 * 1024
PALETTE_ADDR = 0x8200

# Palette: backdrop black, then a few NES colours. Colour 3 is what tile 0
# selects; the rest is filler so no palette entry is left undefined.
PALETTE = [
    0x0F, 0x01, 0x02, 0x21,
    0x0F, 0x11, 0x12, 0x13,
    0x0F, 0x21, 0x22, 0x23,
    0x0F, 0x31, 0x32, 0x33,
    0x0F, 0x01, 0x02, 0x21,
    0x0F, 0x11, 0x12, 0x13,
    0x0F, 0x21, 0x22, 0x23,
    0x0F, 0x31, 0x32, 0x33,
]

# mnemonic -> (opcode, operand kind)
OPS = {
    "sei":     (0x78, None),
    "cld":     (0xD8, None),
    "txs":     (0x9A, None),
    "txa":     (0x8A, None),
    "inx":     (0xE8, None),
    "dex":     (0xCA, None),
    "dey":     (0x88, None),
    "lda_imm": (0xA9, "imm"),
    "ldx_imm": (0xA2, "imm"),
    "ldy_imm": (0xA0, "imm"),
    "cpx_imm": (0xE0, "imm"),
    "sta_abs": (0x8D, "abs"),
    "lda_absx": (0xBD, "abs"),
    "bit_abs": (0x2C, "abs"),
    "jmp":     (0x4C, "abs"),
    "bpl":     (0x10, "rel"),
    "bmi":     (0x30, "rel"),
    "bne":     (0xD0, "rel"),
}

PROGRAM = [
    ("sei", None),
    ("cld", None),
    ("ldx_imm", "$FF"),
    ("txs", None),

    # LaiNES ignores PPU register writes for its first ~30k cycles while the
    # PPU warms up. Burn a little over a frame so the writes below stick; on
    # real hardware this is simply a short delay before setup.
    ("ldx_imm", "$20"),
    ("label", "delay_outer"),
    ("ldy_imm", "$C8"),
    ("label", "delay_inner"),
    ("dey", None),
    ("bne", "delay_inner"),
    ("dex", None),
    ("bne", "delay_outer"),

    # v = $3F00, write the 32 palette bytes.
    ("lda_imm", "$3F"),
    ("sta_abs", "$2006"),
    ("lda_imm", "$00"),
    ("sta_abs", "$2006"),
    ("ldx_imm", "$00"),
    ("label", "palette"),
    ("lda_absx", "$%04X" % PALETTE_ADDR),
    ("sta_abs", "$2007"),
    ("inx", None),
    ("cpx_imm", "$20"),
    ("bne", "palette"),

    # v = $2000, then fill 960 nametable bytes and 64 attribute bytes with 0.
    # A is 0 here and sta does not disturb it.
    ("lda_imm", "$20"),
    ("sta_abs", "$2006"),
    ("lda_imm", "$00"),
    ("sta_abs", "$2006"),
    ("ldx_imm", "$00"),
    ("ldy_imm", "$04"),
    ("label", "fill"),
    ("sta_abs", "$2007"),
    ("inx", None),
    ("bne", "fill"),
    ("dey", None),
    ("bne", "fill"),

    # Scroll to 0,0, background on, NMIs off.
    ("lda_imm", "$00"),
    ("sta_abs", "$2005"),
    ("sta_abs", "$2005"),
    ("sta_abs", "$2006"),
    ("sta_abs", "$2006"),
    ("sta_abs", "$2000"),
    ("lda_imm", "$0A"),
    ("sta_abs", "$2001"),

    # Let one whole frame render with the final palette so the frame captured
    # by the frontend is the steady-state pattern.
    ("label", "clear_vblank"),
    ("bit_abs", "$2002"),
    ("bmi", "clear_vblank"),
    ("label", "next_vblank"),
    ("bit_abs", "$2002"),
    ("bpl", "next_vblank"),

    ("label", "forever"),
    ("jmp", "forever"),
]

def value(operand):
    """Parse "$XX" into an int."""
    return int(operand.lstrip("$"), 16)


def size(kind):
    return {None: 1, "imm": 2, "abs": 3, "rel": 2}[kind]


def assemble(program, base):
    labels = {}
    pc = base
    for mnemonic, operand in program:
        if mnemonic == "label":
            labels[operand] = pc
            continue
        opcode, kind = OPS[mnemonic]
        pc += size(kind)

    out = bytearray()
    pc = base
    for mnemonic, operand in program:
        if mnemonic == "label":
            continue
        opcode, kind = OPS[mnemonic]
        out.append(opcode)
        if kind == "imm":
            out.append(value(operand) & 0xFF)
        elif kind == "abs":
            addr = labels[operand] if operand in labels else value(operand)
            out += struct.pack("<H", addr)
        elif kind == "rel":
            delta = labels[operand] - (pc + 2)
            if not -128 <= delta <= 127:
                raise ValueError("branch to %s out of range" % operand)
            out.append(delta & 0xFF)
        pc += size(kind)

    return bytes(out)


def build_prg():
    prg = bytearray(PRG_SIZE)
    code = assemble(PROGRAM, PRG_BASE)
    if len(code) > PALETTE_ADDR - PRG_BASE:
        raise ValueError("code does not fit before the palette table")

    prg[0:len(code)] = code
    off = PALETTE_ADDR - PRG_BASE
    prg[off:off + len(PALETTE)] = bytes(PALETTE)

    # NMI, RESET and IRQ all point at the reset code; NMIs stay disabled.
    struct.pack_into("<HHH", prg, PRG_SIZE - 6, PRG_BASE, PRG_BASE, PRG_BASE)
    return bytes(prg)


def build_chr():
    chr_rom = bytearray(CHR_SIZE)
    # Tile 0: both bit planes 0xF0 -> colour 3 on the left, colour 0 right.
    for row in range(8):
        chr_rom[row * 2] = 0xF0
        chr_rom[row * 2 + 1] = 0xF0
    return bytes(chr_rom)


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: make_test_rom.py OUT.nes")

    header = b"NES\x1a" + bytes([
        1,     # 16 KiB PRG
        1,     # 8 KiB CHR
        0x01,  # mapper 0, vertical mirroring
        0x00,  # mapper 0, NES 1.0
    ]) + bytes(8)

    with open(sys.argv[1], "wb") as f:
        f.write(header)
        f.write(build_prg())
        f.write(build_chr())

    print("wrote %s (NROM, 16 KiB PRG, 8 KiB CHR)" % sys.argv[1])


if __name__ == "__main__":
    main()
