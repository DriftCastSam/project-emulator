# PYNQ-Z2 hardware notes

## Board

| Item | Value |
|---|---|
| AP SoC | XC7Z020-1CLG400C |
| PS | dual Cortex-A9, 667 MHz |
| DDR3 | 512 MB, 32-bit |
| PL clock | 125 MHz single-ended |
| HDMI out | 3 TMDS data lanes + clock, driven directly from PL |
| USB | one USB 2.0 host port on the PS |
| Audio | ADAU1761 codec (I2C control, I2S data) |
| Storage | microSD |
| Buttons/LEDs | 4 buttons, 4 LEDs, 2 switches, 2 RGB LEDs |

## HDMI out pins

From the Digilent board file (`A.0/part0_pins.xml`), all LVCMOS33:

| Signal | Pin |
|---|---|
| TMDS_OUT_clk_p | L16 |
| TMDS_OUT_clk_n | L17 |
| TMDS_OUT_data_p_0 | K17 |
| TMDS_OUT_data_n_0 | K18 |
| TMDS_OUT_data_p_1 | K19 |
| TMDS_OUT_data_n_1 | J19 |
| TMDS_OUT_data_p_2 | J18 |
| TMDS_OUT_data_n_2 | H18 |
| hdmi_tx_hpd | R19 |
| hdmi_tx_cec | G15 |

The pins are LVCMOS33 in the board file, not TMDS_33. Use LVCMOS33 in the
XDC and let the board's output network do the rest. This matches Digilent's
rgb2dvi reference for this board.

## Clocking

The only PL clock is 125 MHz. The video MMCM generates:

| Clock | Frequency | Use |
|---|---|---|
| pixel | 74.21875 MHz | video timing, scaler, TMDS parallel data |
| serial | 371.09375 MHz | OSERDESE2 high-speed clock |
| ppu | 5.371 MHz | NES PPU dot clock |

`74.21875 * 5 = 371.09375`, so the serial clock is exactly 5x the pixel clock,
which is what 10:1 DDR serialization needs.

## Boot

Boot mode jumper: SD. `BOOT.BIN` must contain FSBL, bitstream, and U-Boot, in
that order. The bitstream is what configures the video path, so the console
shows video as soon as U-Boot loads the FPGA (before Linux).

## Power

HDMI + USB Bluetooth dongle + SD is within the board's USB power budget. Do
not power the board from the USB UART port while the HDMI cable is attached;
use the dedicated 12 V input.
