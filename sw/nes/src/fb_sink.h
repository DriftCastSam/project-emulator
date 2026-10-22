#pragma once

#include "frame_sink.h"

struct orbit_fb;

// Sends frames to the PL through the reserved DDR buffer and paces the
// emulator on the display swap. This is the real console sink.
class FbSink : public FrameSink {
public:
    FbSink();
    ~FbSink() override;

    FbSink(const FbSink&) = delete;
    FbSink& operator=(const FbSink&) = delete;

    bool ok() const { return fb_ != nullptr; }
    void push(const uint16_t* rgb565, int w, int h) override;

private:
    struct orbit_fb* fb_;
};
