VERILATOR ?= verilator
RTL       := ../rtl
VFLAGS    := --binary --timing -Wall -Wno-fatal

.PHONY: run tmds timing dma clean

run: tmds timing dma

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

dma:
	mkdir -p obj/dma
	$(VERILATOR) $(VFLAGS) --top-module tb_fb_dma -Mdir obj/dma -o tb_dma \
		$(RTL)/fb_dma.v tb_fb_dma.sv
	./obj/dma/tb_dma

clean:
	rm -rf obj
