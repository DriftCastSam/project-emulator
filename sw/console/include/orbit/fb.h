/*
 * Orbit console userspace: framebuffer and register access.
 *
 * The PL exposes a 4 KiB register block through UIO and reads a 256x240
 * RGB565 frame from a reserved DDR region through HP0. Software writes the
 * frame, then pokes the copy engine; the PL swaps banks at the next frame
 * start.
 */

#ifndef ORBIT_FB_H
#define ORBIT_FB_H

#include <stddef.h>
#include <stdint.h>

#define ORBIT_FB_WIDTH  256
#define ORBIT_FB_HEIGHT 240
#define ORBIT_FB_PIXELS (ORBIT_FB_WIDTH * ORBIT_FB_HEIGHT)
#define ORBIT_FB_BYTES  (ORBIT_FB_PIXELS * 2u)
#define ORBIT_FB_PHYS_DEFAULT 0x1F000000u

/* Register offsets, see docs/architecture.md. */
#define ORBIT_REG_ID         0x00u
#define ORBIT_REG_CTRL       0x04u
#define ORBIT_REG_STATUS     0x08u
#define ORBIT_REG_FB_ADDR    0x0Cu
#define ORBIT_REG_FB_STRIDE  0x10u
#define ORBIT_REG_DMA_CTRL   0x14u
#define ORBIT_REG_DMA_STATUS 0x18u
#define ORBIT_REG_SCRATCH    0x1Cu

#define ORBIT_CTRL_PATTERN   (1u << 0)
#define ORBIT_CTRL_ANIMATE   (1u << 1)

#define ORBIT_STATUS_LOCKED        (1u << 0)
#define ORBIT_STATUS_VSYNC         (1u << 1)
#define ORBIT_STATUS_FRAME_READY   (1u << 2)
#define ORBIT_STATUS_FRAME_SHIFT   16

#define ORBIT_DMA_START  (1u << 0)
#define ORBIT_DMA_BUSY   (1u << 0)
#define ORBIT_DMA_DONE   (1u << 1)
#define ORBIT_DMA_ERROR  (1u << 2)

struct orbit_fb;

struct orbit_fb *orbit_fb_open(const char *uio_path, const char *mem_path,
                               uint32_t fb_phys);
void orbit_fb_close(struct orbit_fb *fb);

/* Copy a 256x240 RGB565 frame into the DDR buffer and start a copy. */
int orbit_fb_commit(struct orbit_fb *fb, const uint16_t *pixels);

/* Block until the PL has displayed a new frame, or the timeout expires. */
int orbit_fb_wait_frame(struct orbit_fb *fb, int timeout_ms);

uint32_t orbit_fb_frame_count(struct orbit_fb *fb);
uint32_t orbit_fb_status(struct orbit_fb *fb);

/* Helpers, also used by host tests. */
static inline uint16_t orbit_rgb565(uint8_t r, uint8_t g, uint8_t b)
{
    return (uint16_t)(((uint16_t)(r >> 3) << 11) |
                      ((uint16_t)(g >> 2) << 5) |
                      ((uint16_t)(b >> 3)));
}

/* Pack two RGB565 pixels the way the DDR buffer is laid out. */
static inline uint32_t orbit_pack2(uint16_t lo, uint16_t hi)
{
    return (uint32_t)lo | ((uint32_t)hi << 16);
}

/* 0xAARRGGBB to RGB565. */
static inline uint16_t orbit_argb_to_565(uint32_t argb)
{
    return orbit_rgb565((uint8_t)(argb >> 16), (uint8_t)(argb >> 8),
                        (uint8_t)argb);
}

#endif
