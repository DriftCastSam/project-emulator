#!/bin/sh
#
# Build the U-Boot boot script and place the bitstream where genimage can
# find it. The bitstream comes from `make hw`; override the path with
# ORBIT_BITSTREAM if it lives elsewhere.

set -e

BOARD_DIR="$(dirname "$0")"
ORBIT_ROOT="$(cd "$BOARD_DIR/../../.." && pwd)"

"${HOST_DIR}/bin/mkimage" -C none -A arm -T script \
	-d "${BOARD_DIR}/boot.cmd" "${BINARIES_DIR}/boot.scr"

BITSTREAM="${ORBIT_BITSTREAM:-${ORBIT_ROOT}/hw/build/orbit.bin}"

if [ ! -f "$BITSTREAM" ]; then
	echo "ERROR: no raw bitstream at $BITSTREAM" >&2
	echo "       run 'make hw' first, or set ORBIT_BITSTREAM" >&2
	exit 1
fi

install -m 0644 "$BITSTREAM" "${BINARIES_DIR}/system.bin"

# Buildroot names the DTB after the source file; the boot script uses system.dtb.
DTB="${BINARIES_DIR}/zynq-pynq-z2.dtb"
if [ -f "$DTB" ]; then
	install -m 0644 "$DTB" "${BINARIES_DIR}/system.dtb"
else
	echo "ERROR: no DTB at $DTB" >&2
	exit 1
fi
