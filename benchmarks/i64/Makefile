# Makefile - build the wasm module that i64bench.mjs loads.
#
#   make            # builds ops.wasm here AND copies it to
#                   # /tmp/i64bench/ops.wasm (the absolute path is baked into
#                   # i64bench.mjs, so a local build alone would not be found)
#   make clean
#
# Toolchain: a clang that knows the wasm32 target (Debian/Ubuntu: `clang`;
# or `zig cc`). ops.c is freestanding, so there is no libc/linker dependency:
# -nostdlib and --export-all are enough. Override CC_WASM for another clang.
CC_WASM ?= clang
DEST    := /tmp/i64bench

ops.wasm: ops.c
	$(CC_WASM) --target=wasm32 -O3 -nostdlib -Wl,--no-entry -Wl,--export-all -o $@ $<
	mkdir -p $(DEST)
	cp $@ $(DEST)/ops.wasm

clean:
	rm -f ops.wasm $(DEST)/ops.wasm

.PHONY: clean
