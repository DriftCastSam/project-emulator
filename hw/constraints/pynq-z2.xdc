# PYNQ-Z2, XC7Z020-1CLG400C
# HDMI output and board clock. Pin numbers come from the Digilent board file
# (tul.com.tw:pynq-z2:part0:1.0) and match TUL's master XDC.

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# 125 MHz oscillator.
set_property -dict { PACKAGE_PIN H16 IOSTANDARD LVCMOS33 } [get_ports sys_clk]
create_clock -name sys_clk -period 8.000 -waveform {0.000 4.000} [get_ports sys_clk]

# HDMI out. The board file says LVCMOS33 for these pins, but the connector is
# driven as TMDS and every working PYNQ-Z2 design (including TUL's master XDC)
# uses TMDS_33.
set_property -dict { PACKAGE_PIN L16 IOSTANDARD TMDS_33 } [get_ports hdmi_clk_p]
set_property -dict { PACKAGE_PIN L17 IOSTANDARD TMDS_33 } [get_ports hdmi_clk_n]
set_property -dict { PACKAGE_PIN K17 IOSTANDARD TMDS_33 } [get_ports {hdmi_data_p[0]}]
set_property -dict { PACKAGE_PIN K18 IOSTANDARD TMDS_33 } [get_ports {hdmi_data_n[0]}]
set_property -dict { PACKAGE_PIN K19 IOSTANDARD TMDS_33 } [get_ports {hdmi_data_p[1]}]
set_property -dict { PACKAGE_PIN J19 IOSTANDARD TMDS_33 } [get_ports {hdmi_data_n[1]}]
set_property -dict { PACKAGE_PIN J18 IOSTANDARD TMDS_33 } [get_ports {hdmi_data_p[2]}]
set_property -dict { PACKAGE_PIN H18 IOSTANDARD TMDS_33 } [get_ports {hdmi_data_n[2]}]
set_property -dict { PACKAGE_PIN R19 IOSTANDARD LVCMOS33 } [get_ports hdmi_hpd]

# Debug LEDs: LD0 = MMCM locked, LD1 = frame activity.
set_property -dict { PACKAGE_PIN R14 IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN P14 IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
