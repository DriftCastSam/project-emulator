// Host tests for the pure parts of the framebuffer interface.

#include "orbit/fb.h"

#include <stdio.h>

static int failures;

static void expect_u16(const char *name, uint16_t got, uint16_t want)
{
    if (got != want) {
        printf("FAIL %s: got 0x%04x want 0x%04x\n", name, got, want);
        failures++;
    } else {
        printf("ok   %s\n", name);
    }
}

static void expect_u32(const char *name, uint32_t got, uint32_t want)
{
    if (got != want) {
        printf("FAIL %s: got 0x%08x want 0x%08x\n", name, got, want);
        failures++;
    } else {
        printf("ok   %s\n", name);
    }
}

int main(void)
{
    expect_u16("red", orbit_rgb565(255, 0, 0), 0xF800);
    expect_u16("green", orbit_rgb565(0, 255, 0), 0x07E0);
    expect_u16("blue", orbit_rgb565(0, 0, 255), 0x001F);
    expect_u16("white", orbit_rgb565(255, 255, 255), 0xFFFF);
    expect_u16("black", orbit_rgb565(0, 0, 0), 0x0000);

    expect_u16("argb red", orbit_argb_to_565(0xFFFF0000u), 0xF800);
    expect_u16("argb green", orbit_argb_to_565(0xFF00FF00u), 0x07E0);
    expect_u16("argb blue", orbit_argb_to_565(0xFF0000FFu), 0x001F);
    expect_u16("argb colour", orbit_argb_to_565(0xFF123456u), 0x11AA);

    expect_u32("pack", orbit_pack2(0xBEEF, 0x1234), 0x1234BEEFu);

    if (failures == 0) {
        printf("PASS: framebuffer helpers\n");
        return 0;
    }
    printf("FAIL: %d failures\n", failures);
    return 1;
}
