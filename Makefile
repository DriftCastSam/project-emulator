SHELL := /bin/bash
VIVADO_SETTINGS ?= /tools/Xilinx/2025.2/settings64.sh
VERILATOR ?= verilator

RTL  := $(wildcard hw/rtl/*.v hw/rtl/**/*.v)
TB   := $(wildcard hw/sim/*.sv)
LINT := tmds_encoder video_timing test_pattern fb_dma

.PHONY: help lint sim hw sw os clean

help:
	@echo "lint   Verilator lint"
	@echo "sim    Verilator unit testbenches"
	@echo "hw     Vivado bitstream + XSA"
	@echo "sw     cross-build orbit-console"
	@echo "os     Buildroot image"

lint:
	@for m in $(LINT); do \
		$(VERILATOR) --lint-only -Wall -Wno-fatal --top-module $$m hw/rtl/$$m.v || exit 1; \
	done
	@echo "lint clean"

sim:
	@if [ -z "$(TB)" ]; then echo "no testbenches yet"; else \
	$(MAKE) -C hw/sim run; fi

hw:
	source $(VIVADO_SETTINGS) && vivado -mode batch -source hw/scripts/build_vivado.tcl

sw:
	$(MAKE) -C sw/console

os:
	$(MAKE) -C os

clean:
	rm -rf hw/build hw/vivado sw/nes/build sw/console/build
