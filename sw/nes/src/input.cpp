#include "input.h"

#include "gui.hpp"

#include <dirent.h>
#include <fcntl.h>
#include <linux/input.h>
#include <poll.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include <cerrno>
#include <cstdio>
#include <cstring>
#include <thread>

namespace {

enum {
    NES_A      = 1u << 0,
    NES_B      = 1u << 1,
    NES_SELECT = 1u << 2,
    NES_START  = 1u << 3,
    NES_UP     = 1u << 4,
    NES_DOWN   = 1u << 5,
    NES_LEFT   = 1u << 6,
    NES_RIGHT  = 1u << 7,
};

int device_score(int fd)
{
    unsigned long evbit[1] = {0};
    if (ioctl(fd, EVIOCGBIT(0, sizeof(evbit)), evbit) < 0)
        return 0;
    if (!(evbit[0] & (1ul << EV_KEY)))
        return 0;

    unsigned long keybit[(KEY_MAX / (8 * sizeof(unsigned long))) + 1];
    memset(keybit, 0, sizeof(keybit));
    if (ioctl(fd, EVIOCGBIT(EV_KEY, sizeof(keybit)), keybit) < 0)
        return 0;

    auto has = [&](int code) {
        return keybit[code / (8 * sizeof(unsigned long))] &
               (1ul << (code % (8 * sizeof(unsigned long))));
    };

    int score = 0;
    if (has(BTN_SOUTH) || has(BTN_A))
        score += 4;
    if (has(BTN_START))
        score += 2;
    if (has(BTN_DPAD_UP) || has(BTN_TRIGGER))
        score += 1;
    return score;
}

std::string find_gamepad()
{
    DIR* dir = opendir("/dev/input");
    if (!dir)
        return std::string();

    std::string best;
    int best_score = 0;
    struct dirent* ent;

    while ((ent = readdir(dir)) != nullptr) {
        if (strncmp(ent->d_name, "event", 5) != 0)
            continue;
        std::string path = std::string("/dev/input/") + ent->d_name;
        int fd = ::open(path.c_str(), O_RDONLY);
        if (fd < 0)
            continue;
        int score = device_score(fd);
        ::close(fd);
        if (score > best_score) {
            best_score = score;
            best = path;
        }
    }

    closedir(dir);
    return best;
}

} // namespace

Input::~Input()
{
    stop_ = true;
    if (thread_) {
        static_cast<std::thread*>(thread_)->join();
        delete static_cast<std::thread*>(thread_);
        thread_ = nullptr;
    }
    if (fd_ >= 0)
        ::close(fd_);
}

bool Input::open(const std::string& path)
{
    path_ = path.empty() ? find_gamepad() : path;
    if (path_.empty()) {
        fprintf(stderr, "orbit-nes: no gamepad found under /dev/input\n");
        return false;
    }

    fd_ = ::open(path_.c_str(), O_RDONLY);
    if (fd_ < 0) {
        fprintf(stderr, "orbit-nes: cannot open %s: %s\n", path_.c_str(),
                strerror(errno));
        return false;
    }

    fprintf(stderr, "orbit-nes: controller %s\n", path_.c_str());
    thread_ = new std::thread(&Input::run, this);
    return true;
}

void Input::run()
{
    unsigned state = 0;
    int hat_x = 0, hat_y = 0;
    int abs_x = 0, abs_y = 0;

    auto set_bit = [&](unsigned bit, bool on) {
        if (on)
            state |= bit;
        else
            state &= ~bit;
    };

    auto apply_dpad = [&]() {
        set_bit(NES_UP, hat_y < 0 || abs_y < -20000);
        set_bit(NES_DOWN, hat_y > 0 || abs_y > 20000);
        set_bit(NES_LEFT, hat_x < 0 || abs_x < -20000);
        set_bit(NES_RIGHT, hat_x > 0 || abs_x > 20000);
    };

    while (!stop_) {
        struct pollfd pfd = {fd_, POLLIN, 0};
        int rc = poll(&pfd, 1, 200);
        if (rc <= 0)
            continue;

        struct input_event ev;
        ssize_t n = read(fd_, &ev, sizeof(ev));
        if (n != (ssize_t)sizeof(ev))
            continue;

        if (ev.type == EV_KEY) {
            bool down = ev.value != 0;
            switch (ev.code) {
            case BTN_SOUTH:  set_bit(NES_A, down); break;
            case BTN_EAST:   set_bit(NES_B, down); break;
            case BTN_SELECT: set_bit(NES_SELECT, down); break;
            case BTN_START:  set_bit(NES_START, down); break;
            case BTN_DPAD_UP:    set_bit(NES_UP, down); break;
            case BTN_DPAD_DOWN:  set_bit(NES_DOWN, down); break;
            case BTN_DPAD_LEFT:  set_bit(NES_LEFT, down); break;
            case BTN_DPAD_RIGHT: set_bit(NES_RIGHT, down); break;
            default: break;
            }
        } else if (ev.type == EV_ABS) {
            switch (ev.code) {
            case ABS_HAT0X:
                hat_x = ev.value;
                apply_dpad();
                break;
            case ABS_HAT0Y:
                hat_y = ev.value;
                apply_dpad();
                break;
            case ABS_X:
                abs_x = ev.value;
                apply_dpad();
                break;
            case ABS_Y:
                abs_y = ev.value;
                apply_dpad();
                break;
            default:
                break;
            }
        }

        GUI::set_joypad_state((u8)state);
    }
}
