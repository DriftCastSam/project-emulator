#!/bin/sh
#
# Assemble the SD image: FAT boot partition plus ext4 root.

set -e

BOARD_DIR="$(dirname "$0")"

support/scripts/genimage.sh -c "${BOARD_DIR}/genimage.cfg"
