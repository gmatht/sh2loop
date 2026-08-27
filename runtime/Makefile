# Makefile for the C runtime polyfills (runtime/polyfills.c).
#
# Builds the C polyfill library (static + shared, linkable/FFI-callable
# from any backend with libc bindings), runs the self-test oracle
# (diff against real bash builtins), and checks builtin coverage.
#
#   make            — build libsh2poly.a + libsh2poly.so + the C CLI
#   make selftest   — C self-test vs bash reference (the oracle)
#   make coverage   — every sh2perl builtin covered by bash or C
#   make adapters   — build & verify ALL backend adapters on the battery
#   make clean

CC      ?= cc
CFLAGS  ?= -O2 -Wall -Wextra -std=c11
PIC     := -fPIC

LIB      := libsh2poly.a
SHLIB    := libsh2poly.so
OBJ      := polyfills.o
SELFTEST := polyfills-selftest
CLI      := adapters/c/polyfill-cli

# the other backend adapters
RUST_ADAPTER := adapters/rust/sh2poly-adapter
ZIG_ADAPTER  := adapters/zig/sh2poly-adapter
GO_ADAPTER   := adapters/go/sh2poly-adapter
JAVA_SO      := adapters/java/libpolyfills_jni.so
ORACLE       := /tmp/polyfills-c.out

# JAVA_HOME for the JNI shim (adapters/java)
JAVA_HOME ?= $(shell dirname $$(dirname $$(readlink -f $$(which javac))))

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

# --- backend adapters ------------------------------------------------
# Each adapter links/runs libsh2poly and runs the battery
# (adapters/battery.txt) in the C self-test's output format, so all
# adapters can be diffed against the same oracle.

$(RUST_ADAPTER): adapters/rust/main.rs $(LIB)
	rustc -O adapters/rust/main.rs -L . -l static=sh2poly -o $@

$(ZIG_ADAPTER): adapters/zig/main.zig $(LIB)
	zig build-exe adapters/zig/main.zig -I. -L. -lsh2poly -lc -O ReleaseSafe -femit-bin=$@

$(GO_ADAPTER): adapters/go/main.go adapters/go/go.mod $(LIB)
	cd adapters/go && go build -o ../../$@ .

$(JAVA_SO): adapters/java/Polyfills.java adapters/java/polyfills_jni.c $(LIB)
	cd adapters/java && javac Polyfills.java && javac -h . Polyfills.java && \
	$(CC) -shared -fPIC -I"$(JAVA_HOME)/include" -I"$(JAVA_HOME)/include/linux" \
		-o libpolyfills_jni.so polyfills_jni.c ../../libsh2poly.a

ADAPTER_BINS := $(CLI) $(RUST_ADAPTER) $(ZIG_ADAPTER) $(GO_ADAPTER) $(JAVA_SO)

selftest: $(SELFTEST)
	./$(SELFTEST) > $(ORACLE) 2>/dev/null
	bash polyfills-c-ref.sh > /tmp/polyfills-c-ref.out 2>/dev/null
	diff /tmp/polyfills-c-ref.out $(ORACLE)
	@echo "ORACLE PASS: C polyfills match real bash builtins"

# build + verify every backend adapter against the C self-test oracle
adapters: $(SELFTEST) $(ADAPTER_BINS) $(SHLIB)
	./$(SELFTEST) > $(ORACLE) 2>/dev/null
	@echo "== verifying all adapters against the C oracle =="
	@$(CLI) --battery > /tmp/adapter.out 2>/dev/null; \
		diff $(ORACLE) /tmp/adapter.out && echo "OK  c-cli"
	@$(RUST_ADAPTER) > /tmp/adapter.out 2>/dev/null; \
		diff $(ORACLE) /tmp/adapter.out && echo "OK  rust"
	@$(ZIG_ADAPTER) > /tmp/adapter.out 2>/dev/null; \
		diff $(ORACLE) /tmp/adapter.out && echo "OK  zig"
	@$(GO_ADAPTER) > /tmp/adapter.out 2>/dev/null; \
		diff $(ORACLE) /tmp/adapter.out && echo "OK  go"
	@perl adapters/perl/polyfills.pl > /tmp/adapter.out 2>/dev/null; \
		diff $(ORACLE) /tmp/adapter.out && echo "OK  perl"
	@java -Djava.library.path=adapters/java -cp adapters/java Polyfills > /tmp/adapter.out 2>/dev/null; \
		diff $(ORACLE) /tmp/adapter.out && echo "OK  java"
	@python3 adapters/python/polyfills.py --battery > /tmp/adapter.out 2>/dev/null; \
		diff $(ORACLE) /tmp/adapter.out && echo "OK  python"
	@echo "ADAPTERS PASS: all backends match the C polyfill oracle"

coverage:
	python3 check-coverage.py

clean:
	rm -f $(OBJ) $(LIB) $(SHLIB) $(SELFTEST) $(CLI)
	rm -f $(RUST_ADAPTER) $(ZIG_ADAPTER) $(GO_ADAPTER)
	rm -f $(JAVA_SO) adapters/java/*.class adapters/java/Polyfills.h

.PHONY: all selftest adapters coverage clean
