// Framebuffer demo: animated plasma in 256x240, committed once per frame.
//
// This is the first thing to run on the board after the bitstream loads. It
// proves the UIO registers, the DDR frame buffer, the copy engine, the scaler
// and the HDMI link in one go.

#include "orbit/fb.h"

#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

static volatile sig_atomic_t stop;

static void on_signal(int sig)
{
    (void)sig;
    stop = 1;
}

static uint64_t now_ms(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000u + (uint64_t)ts.tv_nsec / 1000000u;
}

int main(int argc, char **argv)
{
    int frames = 0; // 0 = run until interrupted
    if (argc > 1)
        frames = atoi(argv[1]);

    struct orbit_fb *fb = orbit_fb_open("/dev/uio0", "/dev/mem",
                                        ORBIT_FB_PHYS_DEFAULT);
    if (!fb) {
        fprintf(stderr, "cannot open the video device\n");
        return 1;
    }

    struct orbit_fb_info info;
    char line[192];
    int rc = orbit_fb_probe(fb, &info);
    orbit_fb_info_string(&info, line, sizeof(line));
    if (rc != 0) {
        fprintf(stderr, "video registers do not answer (scratch round-trip "
                        "failed): %s\n", line);
        orbit_fb_close(fb);
        return 1;
    }
    printf("video ready: %s\n", line);
    fflush(stdout);

    uint16_t *pixels = malloc(ORBIT_FB_BYTES);
    if (!pixels) {
        orbit_fb_close(fb);
        return 1;
    }

    signal(SIGINT, on_signal);
    signal(SIGTERM, on_signal);

    uint64_t start = now_ms();
    int done = 0;

    for (int f = 0; !stop && (frames == 0 || done < frames); f++) {
        unsigned t = (unsigned)f;

        for (int y = 0; y < ORBIT_FB_HEIGHT; y++) {
            for (int x = 0; x < ORBIT_FB_WIDTH; x++) {
                unsigned v = (unsigned)(x * 5 + t * 3) ^
                             (unsigned)(y * 7 + t * 5);
                unsigned r = (v & 0x1F) << 3;
                unsigned g = ((v >> 2) & 0x3F) << 2;
                unsigned b = ((v >> 1) & 0x1F) << 3;
                pixels[y * ORBIT_FB_WIDTH + x] =
                    orbit_rgb565((uint8_t)r, (uint8_t)g, (uint8_t)b);
            }
        }

        // A white box crossing the screen makes a dropped frame obvious.
        int bx = (t * 3) % (ORBIT_FB_WIDTH - 16);
        for (int y = 100; y < 116; y++)
            for (int x = bx; x < bx + 16; x++)
                pixels[y * ORBIT_FB_WIDTH + x] = 0xFFFF;

        if (orbit_fb_commit(fb, pixels) != 0) {
            fprintf(stderr, "commit failed\n");
            break;
        }

        if (orbit_fb_wait_frame(fb, 100) != 0) {
            char why[192];
            orbit_fb_probe(fb, &info);
            orbit_fb_info_string(&info, why, sizeof(why));
            fprintf(stderr,
                    "no frame from the PL after 100 ms, is the bitstream "
                    "loaded? dma=0x%08x (busy=%u done=%u error=%u swaps=%u)\n",
                    info.dma_status, info.dma_status & 1u,
                    (info.dma_status >> 1) & 1u, (info.dma_status >> 2) & 1u,
                    info.dma_status >> 16);
            fprintf(stderr, "  %s\n", why);
            break;
        }

        done++;
        if ((f & 63) == 0) {
            uint64_t ms = now_ms() - start;
            if (ms > 0)
                printf("%d frames, %.1f fps, status 0x%08x\n", done,
                       1000.0 * done / (double)ms, orbit_fb_status(fb));
        }
    }

    printf("stopped after %d frames\n", done);
    free(pixels);
    orbit_fb_close(fb);
    return 0;
}
