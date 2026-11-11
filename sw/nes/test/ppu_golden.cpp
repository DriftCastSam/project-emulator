// Golden vectors for the hardware PPU testbenches.
//
// Drives the vendored LaiNES PPU directly, with no CPU: it loads a cartridge
// with CHR RAM, fills the video memories with seeded random data, runs one
// frame of PPU dots while changing the scroll and mask registers at fixed dots,
// and records what the PPU did. The testbench replays the same memories and
// per-line state into the RTL and compares every pixel.
//
//   usage: ppu_golden <outdir> <scenario 0..N>
//
// Files written to <outdir> (hex, one value per line, for $readmemh):
//   chr.mem     8192  pattern table bytes
//   nt.mem      4096  nametable space $2000-$2FFF, as the PPU reads it
//   pal.mem       32  palette writes in address order (aliases overwrite)
//   cfg.mem        1  mirroring (0 V, 1 H, 2 one-screen hi, 3 one-screen lo)
//   lines.mem    240  per line: [14:0] V, [17:15] fine X, [18] bg table,
//                     [19] bg on, [20] bg left, [21] gray
//   expect.mem 61440  RGB565, 256 per line
//
// The line state is sampled at dot 320 of the previous line, before the two
// prefetch tiles, and register writes are made at dot 270, after the line's
// horizontal copy at dot 257. That is the scanline-granularity contract of
// phase 5a (docs/architecture.md 6.2).

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <string>

#include "apu.hpp"
#include "cartridge.hpp"
#include "cpu.hpp"
#include "ppu.hpp"

namespace PPU {
extern u32 pixels[256 * 240];
u8 rd(u16 addr);
void wr(u16 addr, u8 v);
} // namespace PPU

namespace {

uint32_t rng_state;

uint32_t rnd()
{
    rng_state ^= rng_state << 13;
    rng_state ^= rng_state >> 17;
    rng_state ^= rng_state << 5;
    return rng_state;
}

struct Line {
    uint32_t word;
};

// Cartridge::load wants a file. NROM-128 with no CHR banks gets 8 KiB of CHR RAM.
std::string make_cart(const std::string& dir)
{
    std::string path = dir + "/cart.nes";
    FILE* f = fopen(path.c_str(), "wb");
    if (!f) { perror(path.c_str()); exit(1); }
    uint8_t header[16] = {'N', 'E', 'S', 0x1A, 1, 0, 0, 0};
    fwrite(header, 1, 16, f);
    uint8_t prg[16384] = {0};
    prg[0x3FFC] = 0x00; prg[0x3FFD] = 0x80;  // reset vector $8000
    fwrite(prg, 1, sizeof prg, f);
    fclose(f);
    return path;
}

void dump(const std::string& path, const uint32_t* v, int n, int digits)
{
    FILE* f = fopen(path.c_str(), "w");
    if (!f) { perror(path.c_str()); exit(1); }
    for (int i = 0; i < n; i++) fprintf(f, "%0*x\n", digits, v[i]);
    fclose(f);
}

uint16_t rgb565(uint32_t p)
{
    return (uint16_t)(((p >> 8) & 0xF800) | ((p >> 5) & 0x07E0) | ((p >> 3) & 0x001F));
}

} // namespace

int main(int argc, char** argv)
{
    if (argc != 3) {
        fprintf(stderr, "usage: %s <outdir> <scenario>\n", argv[0]);
        return 2;
    }
    std::string dir = argv[1];
    int scenario = atoi(argv[2]);
    rng_state = 0x9E3779B9u * (uint32_t)(scenario + 1);
    for (int i = 0; i < 8; i++) rnd();

    APU::init();
    Cartridge::load(make_cart(dir).c_str());
    if (!Cartridge::loaded()) { fprintf(stderr, "cart did not load\n"); return 1; }
    PPU::reset();

    // Scenario knobs. Mirroring cycles through all four modes. 0 is static,
    // 1 and up change scroll and nametable select every few lines, 2 and 4-7
    // also toggle the mask, 4 and 5 pin the scroll near the coarse X wrap so
    // nametable crossing happens on most lines.
    int mirror = scenario % 4;
    PPU::set_mirroring((PPU::Mirroring)mirror);
    bool scroll_changes = scenario >= 1;
    bool mask_changes   = scenario == 2 || scenario >= 4;
    bool near_wrap      = scenario == 4 || scenario == 5;

    // Let the PPU warm up (it ignores register writes for ~30k CPU cycles).
    for (int i = 0; i < 100000; i++) PPU::step();
    while (!(PPU::scanline == 261 && PPU::dot == 0)) PPU::step();

    // Memories, written straight through the PPU bus.
    uint32_t chr[8192], nt[4096], pal[32];
    for (int i = 0; i < 8192; i++) {
        // Mix of dense random tiles and sparse ones so transparent pixels occur.
        uint8_t b = (uint8_t)rnd();
        if ((i >> 4) % 3 == 0) b &= (uint8_t)rnd();
        PPU::wr((u16)i, b);
        chr[i] = b;
    }
    for (int i = 0; i < 4096; i++) PPU::wr((u16)(0x2000 + i), (u8)rnd());
    for (int i = 0; i < 4096; i++) nt[i] = PPU::rd((u16)(0x2000 + i));
    // The raw write sequence is recorded, not the final contents, so the
    // testbench replays the aliasing of $10/$14/$18/$1C onto $00/$04/$08/$0C.
    for (int i = 0; i < 32; i++) {
        pal[i] = rnd() & 0x3F;
        PPU::wr((u16)(0x3F00 + i), (u8)pal[i]);
    }

    // Initial registers: random pattern table, nametable and scroll.
    uint8_t ctrl = (uint8_t)(rnd() & 0x13 & ~0x04);  // nt bits, bg table; no NMI
    ctrl = (uint8_t)((ctrl & 0x03) | ((rnd() & 1) ? 0x10 : 0));
    uint8_t mask = 0x0A | ((rnd() & 1) ? 0x04 * 0 : 0);  // bg on, left column on
    if (scenario == 2) mask = (uint8_t)(0x08 | (rnd() & 0x03));
    PPU::access<true>(0, ctrl);
    PPU::access<true>(1, mask);
    PPU::access<true>(5, (u8)rnd());
    PPU::access<true>(5, (u8)rnd());

    Line lines[240];
    for (int i = 0; i < 240; i++) lines[i].word = 0;

    auto sample = [&](int line) {
        PPU::PpuState st;
        PPU::get_state(st);
        uint32_t w = st.vram_addr & 0x7FFF;
        w |= (uint32_t)(st.fine_x & 7) << 15;
        w |= (uint32_t)PPU::ctrl.bgTbl << 18;
        w |= (uint32_t)PPU::mask.bg << 19;
        w |= (uint32_t)PPU::mask.bgLeft << 20;
        w |= (uint32_t)PPU::mask.gray << 21;
        lines[line].word = w;
    };

    do {
        int sl = PPU::scanline, dot = PPU::dot;

        if (dot == 270 && sl >= 0 && sl <= 238) {
            uint32_t r = rnd();
            if (scroll_changes) {
                if (near_wrap) {
                    // $2005 with X near the right edge of a nametable.
                    PPU::access<true>(5, (u8)(0xE0 | (rnd() & 0x1F)));
                    PPU::access<true>(5, (u8)rnd());
                } else if (r % 3 == 0) {
                    // Direct V write: loads V now, so it lands on the next line.
                    PPU::access<true>(6, (u8)(rnd() & 0x3F));
                    PPU::access<true>(6, (u8)rnd());
                } else if (r % 3 == 1) {
                    // Scroll + nametable select: reaches V one line later.
                    PPU::access<true>(0, (u8)((PPU::ctrl.r & ~0x03) | (rnd() & 3)));
                    PPU::access<true>(5, (u8)rnd());
                    PPU::access<true>(5, (u8)rnd());
                }
            }
            if (mask_changes && (rnd() % 5 == 0)) {
                PPU::access<true>(1, (u8)(0x08 | (rnd() & 0x03)));  // bg on, random clip/gray
            }
            if (mask_changes && (rnd() % 11 == 0)) {
                PPU::access<true>(1, 0x00);  // background off for this line
            }
        }
        if (dot == 320) {
            if (sl == 261) sample(0);
            else if (sl <= 238) sample(sl + 1);
        }
        PPU::step();
    } while (!(PPU::scanline == 240 && PPU::dot == 0));

    uint32_t* expect = new uint32_t[256 * 240];
    for (int i = 0; i < 256 * 240; i++) expect[i] = rgb565(PPU::pixels[i]);

    uint32_t lw[240];
    for (int i = 0; i < 240; i++) lw[i] = lines[i].word;
    uint32_t cfg = (uint32_t)mirror;

    dump(dir + "/chr.mem", chr, 8192, 2);
    dump(dir + "/nt.mem", nt, 4096, 2);
    dump(dir + "/pal.mem", pal, 32, 2);
    dump(dir + "/cfg.mem", &cfg, 1, 1);
    dump(dir + "/lines.mem", lw, 240, 8);
    dump(dir + "/expect.mem", expect, 256 * 240, 4);
    delete[] expect;
    printf("ppu_golden: scenario %d mirroring %d -> %s\n", scenario, mirror, dir.c_str());
    return 0;
}
