#!/bin/sh
#
# Assemble the boot files and copy ROMs into the rootfs.
#
# BOOT.BIN is FSBL + bitstream + U-Boot, built from the XSA so the FSBL uses
# this board's ps7_init and programs the PL before U-Boot starts.

set -e

BOARD_DIR="$(dirname "$0")"
ORBIT_ROOT="$(cd "$BOARD_DIR/../../../.." && pwd)"
TARGET_DIR="$1"
ROMS_DIR="${ORBIT_ROMS_DIR:-${ORBIT_ROOT}/roms}"

"${HOST_DIR}/bin/mkimage" -C none -A arm -T script \
	-d "${BOARD_DIR}/boot.cmd" "${BINARIES_DIR}/boot.scr"

BOOTBIN="${ORBIT_BOOT_BIN:-${ORBIT_ROOT}/hw/build/BOOT.BIN}"

if [ ! -f "$BOOTBIN" ]; then
	"${ORBIT_ROOT}/os/scripts/build_boot_bin.sh"
fi

install -m 0644 "$BOOTBIN" "${BINARIES_DIR}/BOOT.BIN"

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
