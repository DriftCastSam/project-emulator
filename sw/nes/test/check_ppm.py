#!/usr/bin/env python3
"""Check the PPM written by `make test`: header, size, and non-blank frame."""

import sys

WIDTH = 256
HEIGHT = 240


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: check_ppm.py FRAME.ppm")

    path = sys.argv[1]
    with open(path, "rb") as f:
        data = f.read()

    # Header: "P6\n<w> <h>\n<maxval>\n" -- three whitespace separated tokens
    # after the magic, then exactly one byte of whitespace before the pixels.
    parts = data.split(b"\n", 3)
    if len(parts) != 4 or parts[0] != b"P6":
        sys.exit("FAIL: %s is not a binary PPM (P6)" % path)
    try:
        width, height = (int(v) for v in parts[1].split())
        maxval = int(parts[2])
    except ValueError:
        sys.exit("FAIL: malformed PPM header in %s" % path)

    if (width, height, maxval) != (WIDTH, HEIGHT, 255):
        sys.exit("FAIL: expected %dx%d maxval 255, got %dx%d maxval %d"
                 % (WIDTH, HEIGHT, width, height, maxval))

    pixels = parts[3]
    if len(pixels) != width * height * 3:
        sys.exit("FAIL: expected %d pixel bytes, got %d"
                 % (width * height * 3, len(pixels)))

    colours = {pixels[i:i + 3] for i in range(0, len(pixels), 3)}
    print("PPM: %s (%dx%d), distinct colours: %d" % (path, width, height, len(colours)))

    if len(colours) < 2:
        sys.exit("FAIL: frame is blank")

    print("PASS")


if __name__ == "__main__":
    main()
