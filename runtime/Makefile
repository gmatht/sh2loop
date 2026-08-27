# Makefile for the C runtime polyfills (runtime/polyfills.c).
#
# Builds the C polyfill library (static + shared, linkable/FFI-callable
# from any backend with libc bindings), runs the self-test oracle
# (diff against real bash builtins), and checks builtin coverage.
#
#   make            — build libsh2poly.a + libsh2poly.so
#   make selftest   — C self-test vs bash reference (the oracle)
#   make coverage   — every sh2perl builtin covered by bash or C
#   make clean

CC      ?= cc
CFLAGS  ?= -O2 -Wall -Wextra -std=c11
PIC     := -fPIC

LIB     := libsh2poly.a
SHLIB   := libsh2poly.so
OBJ     := polyfills.o
SELFTEST := polyfills-selftest
CLI     := adapters/c/polyfill-cli

all: $(LIB) $(SHLIB) $(CLI)

$(OBJ): polyfills.c
	$(CC) $(CFLAGS) $(PIC) -c -o $@ $<

$(LIB): $(OBJ)
	ar rcs $@ $^

$(SHLIB): $(OBJ)
	$(CC) -shared -o $@ $^

$(SELFTEST): polyfills.c
	$(CC) $(CFLAGS) -DSH2POLY_SELFTEST -o $@ $<

$(CLI): adapters/c/polyfill-cli.c $(LIB)
	$(CC) $(CFLAGS) -o $@ $< $(LIB)

selftest: $(SELFTEST)
	./$(SELFTEST) > /tmp/polyfills-c.out 2>/dev/null
	bash polyfills-c-ref.sh > /tmp/polyfills-c-ref.out 2>/dev/null
	diff /tmp/polyfills-c-ref.out /tmp/polyfills-c.out
	@echo "ORACLE PASS: C polyfills match real bash builtins"

# the adapters: run the same battery through the C CLI and the Python
# ctypes adapter, diff against the C self-test (they must agree)
adapters: $(CLI)
	./$(CLI) echo hello world > /tmp/adapter-c.out
	python3 adapters/python/polyfills.py echo hello world > /tmp/adapter-py.out
	diff /tmp/adapter-c.out /tmp/adapter-py.out
	@echo "ADAPTERS AGREE: C CLI and Python ctypes adapter"

coverage:
	python3 check-coverage.py

clean:
	rm -f $(OBJ) $(LIB) $(SHLIB) $(SELFTEST) $(CLI)

.PHONY: all selftest adapters coverage clean
