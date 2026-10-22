#pragma once
#include <cstddef>
#include <cstring>
#include <string>
#include <Nes_Apu.h>
#include "common.hpp"

// Headless replacement for LaiNES' SDL GUI (upstream src/include/gui.hpp).
// The vendored core only uses new_frame, new_samples, get_joypad_state and
// is_fast_forward; the frame accessors below are for the frontend.
namespace GUI {

// NES screen size.
const unsigned WIDTH  = 256;
const unsigned HEIGHT = 240;

// Called by the PPU once per frame with WIDTH*HEIGHT pixels, 0x00RRGGBB.
// Converts them to RGB565 and sets the frame-ready flag.
void new_frame(u32* pixels);

// Latest converted frame (RGB565, WIDTH*HEIGHT) and its validity.
const u16* frame_rgb565();
bool frame_ready();
void clear_frame_ready();

// Audio is not wired up in this build; the APU still calls this every frame.
void new_samples(const blip_sample_t* samples, size_t count);

// Controller state in NES shift-register order (bit 0 = A).
u8 get_joypad_state(int n);
void set_joypad_state(u8 state);

// No fast-forward in the headless build.
bool is_fast_forward();

}
