SHELL := /bin/bash

CXX ?= g++
CC  ?= gcc
CXXFLAGS ?= -O2 -std=c++14
CFLAGS   ?= -O2 -std=c11 -D_POSIX_C_SOURCE=200809L
WARN := -Wall -Wextra -Wno-unused-value -Wno-multichar
CPPFLAGS := -Iinclude -I../console/include \
            -Ivendor/laines/src/include -Ivendor/laines/lib/include

BUILD := build
BIN   := $(BUILD)/orbit-nes
THREAD := -pthread

CORE_SRC := $(wildcard vendor/laines/src/*.cpp) \
            $(wildcard vendor/laines/src/mappers/*.cpp) \
            $(wildcard vendor/laines/lib/*.cpp)
FE_SRC   := src/gui.cpp src/frame_sink.cpp src/fb_sink.cpp src/input.cpp src/main.cpp
FB_SRC   := ../console/src/fb.c

CORE_OBJ := $(patsubst %.cpp,$(BUILD)/obj/%.o,$(CORE_SRC))
FE_OBJ   := $(patsubst %.cpp,$(BUILD)/obj/%.o,$(FE_SRC))
FB_OBJ   := $(BUILD)/obj/fb.o

.PHONY: all orbit-nes test ppu-golden clean

all: $(BIN)

orbit-nes: $(BIN)

$(BIN): $(CORE_OBJ) $(FE_OBJ) $(FB_OBJ)
	$(CXX) $(CXXFLAGS) $(THREAD) -o $@ $^

# Vendored sources are kept byte-identical to upstream, so their warnings are
# not ours to fix.
$(CORE_OBJ): $(BUILD)/obj/%.o: %.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -c -o $@ $<

$(FE_OBJ): $(BUILD)/obj/%.o: %.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) $(THREAD) $(WARN) $(CPPFLAGS) -c -o $@ $<

$(FB_OBJ): $(FB_SRC)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(CPPFLAGS) -c -o $@ $<

# Golden vector generator for the hardware PPU testbenches (hw/sim). It links the
# vendored core and the frontend's GUI shim, with no CPU and no video sink.
GOLDEN := $(BUILD)/ppu_golden

ppu-golden: $(GOLDEN)

$(GOLDEN): test/ppu_golden.cpp $(CORE_OBJ) $(BUILD)/obj/src/gui.o
	$(CXX) $(CXXFLAGS) $(THREAD) $(WARN) $(CPPFLAGS) -o $@ $^

test: $(BIN)
	@mkdir -p $(BUILD)
	python3 test/make_test_rom.py $(BUILD)/test.nes
	./$(BIN) $(BUILD)/test.nes --frames 3 --ppm $(BUILD)/test.ppm
	python3 test/check_ppm.py $(BUILD)/test.ppm

clean:
	rm -rf $(BUILD)
