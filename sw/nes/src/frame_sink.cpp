#include "frame_sink.h"
#include <cstdio>
#include <vector>

void NullSink::push(const uint16_t* rgb565, int w, int h)
{
    (void)rgb565;
    (void)w;
    (void)h;
}

PpmSink::PpmSink(const std::string& path, int scale)
    : path_(path), scale_(scale > 0 ? scale : 1), ok_(false)
{
}

void PpmSink::push(const uint16_t* rgb565, int w, int h)
{
    FILE* f = fopen(path_.c_str(), "wb");
    if (!f) {
        fprintf(stderr, "ppm: cannot open %s for writing\n", path_.c_str());
        ok_ = false;
        return;
    }

    int out_w = w * scale_;
    int out_h = h * scale_;
    fprintf(f, "P6\n%d %d\n255\n", out_w, out_h);

    std::vector<unsigned char> row((size_t)out_w * 3);
    for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
            uint16_t p = rgb565[y * w + x];
            unsigned r = (p >> 11) & 0x1F;
            unsigned g = (p >> 5)  & 0x3F;
            unsigned b =  p        & 0x1F;
            unsigned char rgb[3] = {
                (unsigned char)((r << 3) | (r >> 2)),
                (unsigned char)((g << 2) | (g >> 4)),
                (unsigned char)((b << 3) | (b >> 2)),
            };
            for (int s = 0; s < scale_; s++) {
                unsigned char* dst = &row[((size_t)x * scale_ + s) * 3];
                dst[0] = rgb[0];
                dst[1] = rgb[1];
                dst[2] = rgb[2];
            }
        }
        for (int s = 0; s < scale_; s++)
            fwrite(row.data(), 3, (size_t)out_w, f);
    }

    ok_ = ferror(f) == 0;
    if (fclose(f) != 0)
        ok_ = false;
    if (!ok_)
        fprintf(stderr, "ppm: failed to write %s\n", path_.c_str());
}
