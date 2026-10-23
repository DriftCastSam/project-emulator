#include <signal.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <string>

#include "apu.hpp"
#include "cartridge.hpp"
#include "cpu.hpp"
#include "fb_sink.h"
#include "frame_sink.h"
#include "gui.hpp"
#include "input.h"

namespace {

volatile sig_atomic_t stop = 0;

void on_signal(int)
{
    stop = 1;
}

void usage(const char* argv0)
{
    fprintf(stderr,
            "usage: %s <rom.nes> [options]\n"
            "  --frames N    stop after N frames (default: forever on video)\n"
            "  --ppm FILE    write the last frame as a binary PPM\n"
            "  --scale N     integer upscale for the PPM output (default 1)\n"
            "  --input PATH  evdev device (default: scan /dev/input)\n"
            "  --fb          force the PL framebuffer sink\n"
            "  --null        no video output (benchmark)\n",
            argv0);
}

} // namespace

int main(int argc, char* argv[])
{
    const char* rom_path = nullptr;
    const char* ppm_path = nullptr;
    const char* input_path = nullptr;
    long frames = -1;
    int scale = 1;
    bool force_fb = false;
    bool force_null = false;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--frames") == 0 && i + 1 < argc) {
            frames = strtol(argv[++i], nullptr, 10);
        } else if (strcmp(argv[i], "--ppm") == 0 && i + 1 < argc) {
            ppm_path = argv[++i];
        } else if (strcmp(argv[i], "--scale") == 0 && i + 1 < argc) {
            scale = (int)strtol(argv[++i], nullptr, 10);
        } else if (strcmp(argv[i], "--input") == 0 && i + 1 < argc) {
            input_path = argv[++i];
        } else if (strcmp(argv[i], "--fb") == 0) {
            force_fb = true;
        } else if (strcmp(argv[i], "--null") == 0) {
            force_null = true;
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
    if ((frames < -1) || scale < 1) {
        fprintf(stderr, "orbit-nes: invalid frame count or scale\n");
        return 2;
    }

    // The APU buffer must exist before Cartridge::load resets the sound chip.
    APU::init();
    Cartridge::load(rom_path);
    if (!Cartridge::loaded()) {
        fprintf(stderr, "orbit-nes: could not load ROM: %s\n", rom_path);
        return 1;
    }

    Input input;
    if (!ppm_path)
        input.open(input_path ? input_path : "");

    PpmSink ppm_sink(ppm_path ? ppm_path : "", scale);
    NullSink null_sink;
    std::unique_ptr<FbSink> fb_sink;

    FrameSink* sink = nullptr;
    if (ppm_path) {
        sink = &ppm_sink;
    } else if (force_null) {
        sink = &null_sink;
    } else {
        fb_sink.reset(new FbSink());
        if (fb_sink->ok()) {
            sink = fb_sink.get();
        } else if (force_fb) {
            fprintf(stderr, "orbit-nes: no video device, use --ppm or --null\n");
            return 1;
        } else {
            sink = &null_sink;
        }
    }

    // A PPM run needs a bounded number of frames; the console runs forever.
    if (frames < 0)
        frames = (sink == fb_sink.get()) ? 0 : 60;

    signal(SIGINT, on_signal);
    signal(SIGTERM, on_signal);

    long done = 0;
    while (!stop && (frames == 0 || done < frames)) {
        CPU::run_frame();

        if (sink != &ppm_sink && GUI::frame_ready()) {
            sink->push(GUI::frame_rgb565(), (int)GUI::WIDTH, (int)GUI::HEIGHT);
            GUI::clear_frame_ready();
        }

        if (sink->failed())
            return 1;

        done++;
    }

    if (!GUI::frame_ready() && sink == &ppm_sink) {
        fprintf(stderr, "orbit-nes: the emulator produced no frame\n");
        return 1;
    }

    if (sink == &ppm_sink) {
        sink->push(GUI::frame_rgb565(), (int)GUI::WIDTH, (int)GUI::HEIGHT);
        if (!ppm_sink.ok())
            return 1;
    }

    return 0;
}
