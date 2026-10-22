#!/bin/bash
#
# Build BOOT.BIN for the PYNQ-Z2: FSBL + bitstream + U-Boot.
#
# The FSBL is generated from the XSA, so its ps7_init matches this board
# (DDR, clocks, MIO). The ZedBoard SPL does not, and hangs before UART.
#
# Inputs (override with env vars):
#   XSA         hw/build/orbit.xsa
#   BIT         hw/build/orbit.bit
#   UBOOT_ELF   os/output/build/uboot-custom/u-boot
#   OUT         hw/build/BOOT.BIN
#
# Requires Vitis (xsct, bootgen).

set -e

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VITIS="${VITIS:-/tools/Xilinx/2025.2/Vitis}"
XSA="${XSA:-$ROOT/hw/build/orbit.xsa}"
BIT="${BIT:-$ROOT/hw/build/orbit.bit}"
UBOOT_ELF="${UBOOT_ELF:-$ROOT/os/output/build/uboot-custom/u-boot}"
OUT="${OUT:-$ROOT/hw/build/BOOT.BIN}"
WS="${WS:-$ROOT/hw/build/fsbl_ws}"

for f in "$XSA" "$BIT" "$UBOOT_ELF"; do
	if [ ! -f "$f" ]; then
		echo "ERROR: missing $f" >&2
		exit 1
	fi
done

if [ ! -x "$VITIS/bin/xsct" ]; then
	echo "ERROR: no xsct at $VITIS/bin/xsct" >&2
	exit 1
fi

. "$VITIS/settings64.sh"

rm -rf "$WS"
mkdir -p "$WS"

cat > "$WS/fsbl.tcl" <<EOF
setws $WS
createhw -name orbit_hw -hwspec $XSA
createapp -name fsbl -app {Zynq FSBL} -proc ps7_cortexa9_0 -hw orbit_hw
EOF

"$VITIS/bin/xsct" "$WS/fsbl.tcl"

FSBL="$WS/orbit_hw/zynq_fsbl/fsbl.elf"
if [ ! -f "$FSBL" ]; then
	echo "ERROR: FSBL build failed, no $FSBL" >&2
	exit 1
fi

cat > "$WS/orbit.bif" <<EOF
the_ROM_image:
{
  [bootloader] $FSBL
  $BIT
  $UBOOT_ELF
}
EOF

"$VITIS/bin/bootgen" -image "$WS/orbit.bif" -arch zynq -o "$OUT" -w on

echo "BOOT.BIN: $OUT"
