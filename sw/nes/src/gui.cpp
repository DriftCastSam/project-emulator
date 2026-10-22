#include "gui.hpp"

#include <atomic>

// The vendored core still calls the four upstream GUI hooks. Everything SDL
// related is gone: the frame is converted to RGB565 here and picked up by the
// frontend through frame_rgb565().
namespace GUI {

namespace {

u16 frame[WIDTH * HEIGHT];
bool frame_ready_flag = false;

// Controller 0 state, NES order: A B Select Start Up Down Left Right.
// The evdev thread publishes with a relaxed store; the CPU core reads it.
std::atomic<u8> controller_state{0};

} // namespace

void new_frame(u32* pixels)
{
    for (unsigned i = 0; i < WIDTH * HEIGHT; i++) {
        u32 p = pixels[i];             // 0x00RRGGBB
        frame[i] = (u16)(((p >> 8)  & 0xF800) |
                         ((p >> 5)  & 0x07E0) |
                         ((p >> 3)  & 0x001F));
    }
    frame_ready_flag = true;
}

const u16* frame_rgb565()
{
    return frame;
}

bool frame_ready()
{
    return frame_ready_flag;
}

void clear_frame_ready()
{
    frame_ready_flag = false;
}

void new_samples(const blip_sample_t* samples, size_t count)
{
    (void)samples;
    (void)count;
}

u8 get_joypad_state(int n)
{
    return n == 0 ? controller_state.load(std::memory_order_relaxed) : 0;
}

void set_joypad_state(u8 state)
{
    controller_state.store(state, std::memory_order_relaxed);
}

bool is_fast_forward()
{
    return false;
}

}
