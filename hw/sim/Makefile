VERILATOR ?= verilator
RTL       := ../rtl
VFLAGS    := --binary --timing -Wall -Wno-fatal

.PHONY: run tmds timing clean

run: tmds timing

tmds:
	mkdir -p obj/tmds
	$(VERILATOR) $(VFLAGS) --top-module tb_tmds_encoder -Mdir obj/tmds -o tb_tmds \
		$(RTL)/tmds_encoder.v tb_tmds_encoder.sv
	./obj/tmds/tb_tmds

timing:
	mkdir -p obj/timing
	$(VERILATOR) $(VFLAGS) --top-module tb_video_timing -Mdir obj/timing -o tb_timing \
		$(RTL)/video_timing.v tb_video_timing.sv
	./obj/timing/tb_timing

clean:
	rm -rf obj
