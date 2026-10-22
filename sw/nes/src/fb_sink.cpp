#include "fb_sink.h"

#include "orbit/fb.h"

#include <cstdio>

FbSink::FbSink()
    : fb_(orbit_fb_open("/dev/uio0", "/dev/mem", ORBIT_FB_PHYS_DEFAULT))
{
    if (!fb_)
        fprintf(stderr, "orbit-nes: video device unavailable\n");
}

FbSink::~FbSink()
{
    orbit_fb_close(fb_);
}

void FbSink::push(const uint16_t* rgb565, int w, int h)
{
    if (!fb_ || w != ORBIT_FB_WIDTH || h != ORBIT_FB_HEIGHT)
        return;

    orbit_fb_commit(fb_, rgb565);
    // Blocks until the PL has copied and swapped the bank, which is also the
    // frame pacing for the console.
    orbit_fb_wait_frame(fb_, 100);
}
