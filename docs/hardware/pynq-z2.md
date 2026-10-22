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
| Console UART | PS UART1, MIO 48/49, 115200 8N1, on the micro-USB bridge |
| Audio | ADAU1761 codec (I2C control, I2S data) |
| Storage | microSD |
| Buttons/LEDs | 4 buttons, 4 LEDs, 2 switches, 2 RGB LEDs |

## HDMI out pins

From the Digilent board file (`A.0/part0_pins.xml`):

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

The board XML lists the data and clock pins as LVCMOS33, but the connector is
TMDS and TUL's master XDC, the PYNQ base overlay, and every working PYNQ-Z2
HDMI design constrain them as TMDS_33. Use TMDS_33. The HPD and CEC pins stay
LVCMOS33.

## Clocking

The only PL clock is 125 MHz. Two MMCMs turn it into the video clocks:

| Clock | Frequency | Use |
|---|---|---|
| pixel | 74.21875 MHz | video timing, scaler, TMDS parallel data |
| serial | 371.09375 MHz | OSERDESE2 high-speed clock |
| ppu | 5.37 MHz | NES PPU dot clock (M5) |

One MMCM cannot make both 74.21875 and 371.09375 MHz from 125 MHz: the
fractional multiplier would need 5.9375, and the hardware granularity is
0.125. So:

- MMCM1: 125 MHz x 7.125 / 12 = 74.21875 MHz (VCO 890.625 MHz)
- MMCM2: 74.21875 MHz x 10 = 742.1875 MHz VCO, /2 = 371.09375 MHz serial,
  /10 = 74.21875 MHz

The serial clock is exactly 5x the pixel clock, which is what 10:1 DDR
serialization needs. Pixel logic runs from a global BUFG: the frame store is
a RAMB array that spans clock regions, and a regional BUFR cannot drive it.
The serial clock uses a BUFIO, as the OSERDESE2 requires.

## Boot

The TUL board preset enables PS UART0 and disables UART1, but the USB-UART
bridge is wired to UART1. The build overrides the preset to enable UART1 on
MIO 48/49; without it the FSBL, U-Boot and Linux console are all silent.

Boot mode jumper: SD. `BOOT.BIN` is FSBL + bitstream + U-Boot. The FSBL is
generated from our XSA, so its `ps7_init` matches this board's DDR, clocks,
and MIO, and it programs the PL before U-Boot runs. This replaces the ZedBoard
SPL, which hangs before UART on PYNQ-Z2.

## Power

HDMI + USB Bluetooth dongle + SD is within the board's USB power budget. Do
not power the board from the USB UART port while the HDMI cable is attached;
use the dedicated 12 V input.
