#pragma once
#include <cstdint>
#include <string>

// The frontend writes finished frames through this interface, so the video
// backend can be swapped (PPM today, DDR framebuffer later) without touching
// the emulator loop.
class FrameSink
{
  public:
    virtual ~FrameSink() {}

    // Pixels are RGB565, row-major, w*h entries.
    virtual void push(const uint16_t* rgb565, int w, int h) = 0;

    // True once the backend has given up, so the frontend can exit instead of
    // spinning on a display that will never update.
    virtual bool failed() const { return false; }
};

class NullSink : public FrameSink
{
  public:
    void push(const uint16_t* rgb565, int w, int h) override;
};

// Writes a binary PPM (P6, 8-bit RGB), optionally nearest-neighbour scaled.
class PpmSink : public FrameSink
{
  public:
    PpmSink(const std::string& path, int scale = 1);

    void push(const uint16_t* rgb565, int w, int h) override;

    bool ok() const { return ok_; }

  private:
    std::string path_;
    int scale_;
    bool ok_;
};
