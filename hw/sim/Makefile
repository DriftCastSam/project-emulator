VERILATOR ?= verilator
RTL       := ../rtl
VFLAGS    := --binary --timing -Wall -Wno-fatal

.PHONY: run tmds timing dma ppu clean

run: tmds timing dma ppu

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

# Background renderer vs. golden frames from the vendored LaiNES PPU. The golden
# tool is built from sw/nes and run once per scenario; each scenario changes the
# mirroring mode, scroll pattern and mask behaviour.
GOLDEN    := ../../sw/nes/build/ppu_golden
SCENARIOS := 0 1 2 3 4 5 6 7

ppu:
	$(MAKE) -C ../../sw/nes ppu-golden
	mkdir -p obj/ppu
	$(VERILATOR) $(VFLAGS) --top-module tb_ppu_render -Mdir obj/ppu -o tb_ppu \
		$(RTL)/ppu_render.v $(RTL)/ppu_bg.v $(RTL)/ppu_mem.v $(RTL)/ppu_pal.v \
		$(RTL)/nes_pal_rom.v tb_ppu_render.sv
	@for s in $(SCENARIOS); do \
		mkdir -p obj/ppu/vec$$s; \
		$(GOLDEN) obj/ppu/vec$$s $$s >/dev/null || exit 1; \
		./obj/ppu/tb_ppu +vec=obj/ppu/vec$$s || exit 1; \
	done

clean:
	rm -rf obj
