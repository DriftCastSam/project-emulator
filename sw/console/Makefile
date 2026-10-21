CC      ?= cc
CFLAGS  ?= -O2 -Wall -Wextra -std=c11
CPPFLAGS += -Iinclude -D_POSIX_C_SOURCE=200809L

.PHONY: all check clean

all: fbdemo

fbdemo: src/fbdemo.c src/fb.c include/orbit/fb.h
	$(CC) $(CPPFLAGS) $(CFLAGS) -o $@ src/fbdemo.c src/fb.c

tests/test_convert: tests/test_convert.c include/orbit/fb.h
	$(CC) $(CPPFLAGS) $(CFLAGS) -o $@ tests/test_convert.c

check: tests/test_convert
	./tests/test_convert

clean:
	rm -f fbdemo tests/test_convert
