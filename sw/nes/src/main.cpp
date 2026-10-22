#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>

#include "apu.hpp"
#include "cartridge.hpp"
#include "cpu.hpp"
#include "gui.hpp"
#include "frame_sink.h"

namespace {

void usage(const char* argv0)
{
    fprintf(stderr,
            "usage: %s <rom.nes> [--frames N] [--ppm out.ppm] [--scale N]\n"
            "  --frames N    number of frames to run (default 60)\n"
            "  --ppm FILE    write the last frame as a binary PPM\n"
            "  --scale N     integer upscale for the PPM output (default 1)\n",
            argv0);
}

} // namespace

int main(int argc, char* argv[])
{
    const char* rom_path = nullptr;
    const char* ppm_path = nullptr;
    long frames = 60;
    int scale = 1;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--frames") == 0 && i + 1 < argc) {
            frames = strtol(argv[++i], nullptr, 10);
        } else if (strcmp(argv[i], "--ppm") == 0 && i + 1 < argc) {
            ppm_path = argv[++i];
        } else if (strcmp(argv[i], "--scale") == 0 && i + 1 < argc) {
            scale = (int)strtol(argv[++i], nullptr, 10);
        } else if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            usage(argv[0]);
            return 0;
        } else if (argv[i][0] == '-') {
            fprintf(stderr, "orbit-nes: unknown option %s\n", argv[i]);
            usage(argv[0]);
            return 2;
        } else if (!rom_path) {
            rom_path = argv[i];
        } else {
            fprintf(stderr, "orbit-nes: unexpected argument %s\n", argv[i]);
            usage(argv[0]);
            return 2;
        }
    }

    if (!rom_path) {
        usage(argv[0]);
        return 2;
    }
    if (frames < 1 || scale < 1) {
        fprintf(stderr, "orbit-nes: --frames and --scale must be positive\n");
        return 2;
    }

    // The APU buffer must exist before Cartridge::load resets the sound chip.
    APU::init();
    Cartridge::load(rom_path);
    if (!Cartridge::loaded()) {
        fprintf(stderr, "orbit-nes: could not load ROM: %s\n", rom_path);
        return 1;
    }

    // run_frame() advances the CPU and PPU through one full frame, so the
    // loop itself is the frame pacing; no sleep or busy wait is needed here.
    for (long i = 0; i < frames; i++)
        CPU::run_frame();

    if (!GUI::frame_ready()) {
        fprintf(stderr, "orbit-nes: the emulator produced no frame\n");
        return 1;
    }

    NullSink null_sink;
    PpmSink ppm_sink(ppm_path ? ppm_path : "", scale);
    FrameSink* sink = ppm_path ? static_cast<FrameSink*>(&ppm_sink)
                               : static_cast<FrameSink*>(&null_sink);

    sink->push(GUI::frame_rgb565(), (int)GUI::WIDTH, (int)GUI::HEIGHT);

    if (ppm_path && !ppm_sink.ok())
        return 1;

    return 0;
}
