# Build the PYNQ-Z2 console bitstream.
#   vivado -mode batch -source hw/scripts/build_vivado.tcl
#
# Produces:
#   hw/build/vivado/orbit.runs/impl_1/system_wrapper.bit
#   hw/build/orbit.xsa
#   hw/build/timing_summary.rpt
#   hw/build/utilization.rpt

set script_dir [file dirname [file normalize [info script]]]
set root       [file normalize [file join $script_dir ../..]]
set build_dir  [file join $root hw build]
set proj_dir   [file join $build_dir vivado]

file mkdir $build_dir

if {[llength [get_projects -quiet]] > 0} {
    close_project
}

create_project orbit $proj_dir -part xc7z020clg400-1 -force
set_property board_part tul.com.tw:pynq-z2:part0:1.0 [current_project]
set_property target_language Verilog [current_project]

add_files [glob [file join $root hw rtl *.v]]
add_files -fileset constrs_1 [file join $root hw constraints pynq-z2.xdc]
add_files -fileset constrs_1 [file join $root hw constraints pynq-z2-timing.xdc]
set_property used_in_synthesis false [get_files pynq-z2-timing.xdc]

# ---------------------------------------------------------------- block design
create_bd_design system

create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7 ps7
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
    -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable"} \
    [get_bd_cells ps7]

set_property -dict [list CONFIG.PCW_USE_S_AXI_HP0 {1}] [get_bd_cells ps7]

create_bd_cell -type module -reference orbit_video video

# 125 MHz board oscillator into the video block.
create_bd_port -dir I -type clk -freq_hz 125000000 sys_clk
connect_bd_net [get_bd_ports sys_clk] [get_bd_pins video/clk125]

# AXI4-Lite control, plus the clock and reset the automation wires up.
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
    -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} \
              Master {/ps7/M_AXI_GP0} Slave {/video/S_AXI} \
              ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0} } \
    [get_bd_intf_pins video/S_AXI]

# AXI4 read master -> HP0, for the DDR to frame-store copy. HP0 is AXI3, so
# the master goes through a protocol converter. The axi4 automation rule does
# not accept an AXI4 master into HP0, so this path is wired by hand.
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_protocol_converter pc
set_property -dict [list CONFIG.SI_PROTOCOL {AXI4} CONFIG.MI_PROTOCOL {AXI3} \
    CONFIG.DATA_WIDTH {64} CONFIG.ID_WIDTH {6} CONFIG.ADDR_WIDTH {32} \
    CONFIG.READ_WRITE_MODE {READ_WRITE}] [get_bd_cells pc]

connect_bd_intf_net [get_bd_intf_pins video/M_AXI] [get_bd_intf_pins pc/S_AXI]
connect_bd_intf_net [get_bd_intf_pins pc/M_AXI] [get_bd_intf_pins ps7/S_AXI_HP0]
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins pc/aclk] [get_bd_pins ps7/S_AXI_HP0_ACLK]
connect_bd_net [get_bd_pins rst_ps7_100M/peripheral_aresetn] [get_bd_pins pc/aresetn]

assign_bd_address -target_address_space /video/M_AXI \
    [get_bd_addr_segs ps7/S_AXI_HP0/HP0_DDR_LOWOCM] -force

# HDMI pins.
foreach p {hdmi_clk_p hdmi_clk_n hdmi_hpd} {
    create_bd_port -dir O $p
    connect_bd_net [get_bd_ports $p] [get_bd_pins video/$p]
}
foreach p {hdmi_data_p hdmi_data_n} {
    create_bd_port -dir O -from 2 -to 0 $p
    connect_bd_net [get_bd_ports $p] [get_bd_pins video/$p]
}
create_bd_port -dir O -from 1 -to 0 led
connect_bd_net [get_bd_ports led] [get_bd_pins video/led]

validate_bd_design
save_bd_design

make_wrapper -files [get_files system.bd] -top
set wrapper [file join $proj_dir orbit.srcs sources_1 bd system hdl system_wrapper.v]
add_files -norecurse $wrapper
set_property top system_wrapper [current_fileset]
update_compile_order -fileset sources_1

# --------------------------------------------------------------------- build
launch_runs synth_1 -jobs 8
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    error "synthesis failed, see $proj_dir/orbit.runs/synth_1/runme.log"
}

launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "implementation failed, see $proj_dir/orbit.runs/impl_1/runme.log"
}

open_run impl_1
report_timing_summary -file [file join $build_dir timing_summary.rpt]
report_utilization    -file [file join $build_dir utilization.rpt]
report_clock_utilization -file [file join $build_dir clock_utilization.rpt]

write_hw_platform -fixed -include_bit -force [file join $build_dir orbit.xsa]

puts "BUILD OK"
puts "bitstream: [file join $proj_dir orbit.runs impl_1 system_wrapper.bit]"
