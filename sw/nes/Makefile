SHELL := /bin/bash
CXX ?= g++
CXXFLAGS ?= -O2 -std=c++14
WARN := -Wall -Wextra -Wno-unused-value -Wno-multichar
CPPFLAGS := -Iinclude -Ivendor/laines/src/include -Ivendor/laines/lib/include

BUILD := build
BIN   := $(BUILD)/orbit-nes

CORE_SRC := $(wildcard vendor/laines/src/*.cpp) \
            $(wildcard vendor/laines/src/mappers/*.cpp) \
            $(wildcard vendor/laines/lib/*.cpp)
FE_SRC   := src/gui.cpp src/frame_sink.cpp src/main.cpp
SRC      := $(CORE_SRC) $(FE_SRC)
CORE_OBJ := $(patsubst %.cpp,$(BUILD)/obj/%.o,$(CORE_SRC))
FE_OBJ   := $(patsubst %.cpp,$(BUILD)/obj/%.o,$(FE_SRC))

.PHONY: all orbit-nes test clean

all: $(BIN)

orbit-nes: $(BIN)

$(BIN): $(CORE_OBJ) $(FE_OBJ)
	$(CXX) $(CXXFLAGS) -o $@ $^

# Vendored sources are kept byte-identical to upstream, so their warnings are
# not ours to fix.
$(CORE_OBJ): $(BUILD)/obj/%.o: %.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -c -o $@ $<

$(FE_OBJ): $(BUILD)/obj/%.o: %.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) $(WARN) $(CPPFLAGS) -c -o $@ $<

test: $(BIN)
	@mkdir -p $(BUILD)
	python3 test/make_test_rom.py $(BUILD)/test.nes
	./$(BIN) $(BUILD)/test.nes --frames 3 --ppm $(BUILD)/test.ppm
	python3 test/check_ppm.py $(BUILD)/test.ppm

clean:
	rm -rf $(BUILD)
