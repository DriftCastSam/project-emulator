#!/bin/sh
#
# Build the U-Boot boot script and place the bitstream where genimage can
# find it. The bitstream comes from `make hw`; override the path with
# ORBIT_BITSTREAM if it lives elsewhere.

set -e

BOARD_DIR="$(dirname "$0")"
ORBIT_ROOT="$(cd "$BOARD_DIR/../../../.." && pwd)"
TARGET_DIR="$1"
ROMS_DIR="${ORBIT_ROMS_DIR:-${ORBIT_ROOT}/roms}"

"${HOST_DIR}/bin/mkimage" -C none -A arm -T script \
	-d "${BOARD_DIR}/boot.cmd" "${BINARIES_DIR}/boot.scr"

BITSTREAM="${ORBIT_BITSTREAM:-${ORBIT_ROOT}/hw/build/orbit.bin}"

if [ ! -f "$BITSTREAM" ]; then
	echo "ERROR: no raw bitstream at $BITSTREAM" >&2
	echo "       run 'make hw' first, or set ORBIT_BITSTREAM" >&2
	exit 1
fi

install -m 0644 "$BITSTREAM" "${BINARIES_DIR}/system.bin"

# Bring-your-own ROMs. Nothing here is committed: roms/ is gitignored, and
# commercial ROMs are the builder's responsibility.
mkdir -p "${TARGET_DIR}/roms"
if [ -d "$ROMS_DIR" ]; then
	for rom in "$ROMS_DIR"/*.nes; do
		[ -e "$rom" ] || continue
		install -m 0644 "$rom" "${TARGET_DIR}/roms/"
	done
fi

# Buildroot names the DTB after the source file; the boot script uses system.dtb.
DTB="${BINARIES_DIR}/zynq-pynq-z2.dtb"
if [ -f "$DTB" ]; then
	install -m 0644 "$DTB" "${BINARIES_DIR}/system.dtb"
else
	echo "ERROR: no DTB at $DTB" >&2
	exit 1
fi
