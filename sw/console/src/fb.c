// UIO register access and the DDR -> PL frame handoff.

#include "orbit/fb.h"

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

struct orbit_fb {
    int uio_fd;
    int mem_fd;
    volatile uint32_t *regs;
    volatile uint32_t *mem;
    size_t regs_len;
    size_t mem_len;
};

static uint64_t now_ms(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000u + (uint64_t)ts.tv_nsec / 1000000u;
}

static uint32_t reg_read(struct orbit_fb *fb, uint32_t off)
{
    return fb->regs[off / 4u];
}

static void reg_write(struct orbit_fb *fb, uint32_t off, uint32_t value)
{
    fb->regs[off / 4u] = value;
}

struct orbit_fb *orbit_fb_open(const char *uio_path, const char *mem_path,
                               uint32_t fb_phys)
{
    struct orbit_fb *fb = calloc(1, sizeof(*fb));
    if (!fb)
        return NULL;

    fb->regs_len = 0x1000;
    fb->mem_len = ORBIT_FB_BYTES;

    fb->uio_fd = open(uio_path, O_RDWR | O_SYNC);
    if (fb->uio_fd < 0) {
        perror(uio_path);
        goto fail;
    }

    fb->regs = mmap(NULL, fb->regs_len, PROT_READ | PROT_WRITE, MAP_SHARED,
                    fb->uio_fd, 0);
    if (fb->regs == MAP_FAILED) {
        perror("mmap uio");
        goto fail;
    }

    fb->mem_fd = open(mem_path, O_RDWR | O_SYNC);
    if (fb->mem_fd < 0) {
        perror(mem_path);
        goto fail;
    }

    fb->mem = mmap(NULL, fb->mem_len, PROT_READ | PROT_WRITE, MAP_SHARED,
                   fb->mem_fd, (off_t)fb_phys);
    if (fb->mem == MAP_FAILED) {
        perror("mmap fb");
        goto fail;
    }

    // Framebuffer path, test pattern off.
    reg_write(fb, ORBIT_REG_FB_ADDR, fb_phys);
    reg_write(fb, ORBIT_REG_FB_STRIDE, ORBIT_FB_WIDTH * 2u);
    reg_write(fb, ORBIT_REG_CTRL, 0);

    return fb;

fail:
    orbit_fb_close(fb);
    return NULL;
}

void orbit_fb_close(struct orbit_fb *fb)
{
    if (!fb)
        return;
    if (fb->mem && fb->mem != MAP_FAILED)
        munmap((void *)fb->mem, fb->mem_len);
    if (fb->regs && fb->regs != MAP_FAILED)
        munmap((void *)fb->regs, fb->regs_len);
    if (fb->mem_fd >= 0)
        close(fb->mem_fd);
    if (fb->uio_fd >= 0)
        close(fb->uio_fd);
    free(fb);
}

int orbit_fb_commit(struct orbit_fb *fb, const uint16_t *pixels)
{
    if (!fb || !pixels)
        return -1;

    // Two pixels per 32-bit store; the mapping is uncached.
    for (size_t i = 0; i < ORBIT_FB_PIXELS / 2u; i++) {
        fb->mem[i] = orbit_pack2(pixels[2u * i], pixels[2u * i + 1u]);
    }

    __sync_synchronize();
    reg_write(fb, ORBIT_REG_DMA_CTRL, ORBIT_DMA_START);
    return 0;
}

int orbit_fb_wait_frame(struct orbit_fb *fb, int timeout_ms)
{
    if (!fb)
        return -1;

    uint32_t start = reg_read(fb, ORBIT_REG_STATUS) >> ORBIT_STATUS_FRAME_SHIFT;
    uint64_t deadline = now_ms() + (uint64_t)timeout_ms;

    while (now_ms() <= deadline) {
        uint32_t now = reg_read(fb, ORBIT_REG_STATUS) >> ORBIT_STATUS_FRAME_SHIFT;
        if (now != start)
            return 0;
        struct timespec nap = {0, 1000000};
        nanosleep(&nap, NULL);
    }

    return -1;
}

uint32_t orbit_fb_frame_count(struct orbit_fb *fb)
{
    return reg_read(fb, ORBIT_REG_STATUS) >> ORBIT_STATUS_FRAME_SHIFT;
}

uint32_t orbit_fb_status(struct orbit_fb *fb)
{
    return reg_read(fb, ORBIT_REG_STATUS);
}
