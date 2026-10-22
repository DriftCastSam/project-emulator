#pragma once

#include <string>

// Reads a Linux evdev gamepad and publishes the NES button byte through
// GUI::set_joypad_state. One reader thread, one atomic byte.
class Input {
public:
    Input() = default;
    ~Input();

    Input(const Input&) = delete;
    Input& operator=(const Input&) = delete;

    // Empty path: scan /dev/input/event* for the best gamepad.
    bool open(const std::string& path);
    bool ok() const { return fd_ >= 0; }
    const std::string& path() const { return path_; }

private:
    void run();

    int fd_ = -1;
    std::string path_;
    bool stop_ = false;
    void* thread_ = nullptr;
};
