#include "fb_sink.h"

#include "orbit/fb.h"

#include <cstdio>
#include <cstring>

FbSink::FbSink()
    : fb_(orbit_fb_open("/dev/uio0", "/dev/mem", ORBIT_FB_PHYS_DEFAULT)),
      failed_(fb_ == nullptr)
{
    if (!fb_) {
        fprintf(stderr, "orbit-nes: video device unavailable\n");
        return;
    }

    // Print what the PL answered so the log says whether the registers, the
    // frame buffer and the copy engine are alive before the first frame.
    struct orbit_fb_info info;
    char line[192];
    int rc = orbit_fb_probe(fb_, &info);
    orbit_fb_info_string(&info, line, sizeof(line));
    fprintf(stderr, "orbit-nes: video %s: %s\n", rc == 0 ? "ready" : "error",
            line);
}

FbSink::~FbSink()
{
    orbit_fb_close(fb_);
}

void FbSink::report(const char* what)
{
    struct orbit_fb_info info;
    char line[192];

    if (fb_ && orbit_fb_probe(fb_, &info) == 0) {
        orbit_fb_info_string(&info, line, sizeof(line));
    } else {
        strcpy(line, "registers unreadable");
    }

    fprintf(stderr, "orbit-nes: %s, display stopped: %s\n", what, line);
    failed_ = true;
}

void FbSink::push(const uint16_t* rgb565, int w, int h)
{
    if (failed_ || !fb_ || w != ORBIT_FB_WIDTH || h != ORBIT_FB_HEIGHT)
        return;

    if (orbit_fb_commit(fb_, rgb565) != 0) {
        report("frame commit failed");
        return;
    }

    // Blocks until the PL has copied and swapped the bank, which is also the
    // frame pacing for the console. A timeout means the copy engine never
    // finished, so the display is stuck on the test pattern.
    if (orbit_fb_wait_frame(fb_, 100) != 0) {
        report("no frame from the PL");
    }
}
