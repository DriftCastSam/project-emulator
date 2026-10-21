# Clock-domain crossing constraints, applied during implementation only.
# The block design creates clk_fpga_0 and sys_clk, and the video MMCM creates
# clk_pixel, so these clocks do not exist yet during synthesis.

set_clock_groups -asynchronous \
    -group [get_clocks clk_fpga_0] \
    -group [get_clocks sys_clk] \
    -group [get_clocks -filter {NAME =~ *clk_pixel_raw*}]
