#!/usr/bin/env bash
# install-bench-toolchain.sh — provision what docs/BASH_BENCH.md's benchmarks need
# and this box does not have yet. One step per missing piece, each
# IDEMPOTENT (re-running skips what is already installed) and each ending in
# a VERIFICATION that prints PASS/SKIP, so a step that silently did nothing
# cannot pass for done.
#
# The pieces (docs/BASH_BENCH.md §6, §8, §9, §12):
#   node      the JS columns of every suite (§1 `bench.sh`, §4.1
#             `bench_sqrt.sh`, §6/§8) — installed from nodejs.org into
#             ~/.local/<node-ver>/ when no node and no passwordless sudo.
#             (shellcheck is NOT fetched — separate concern, see harness/lint.sh)
#   bench-c   the §6 C column (shellbench benches rendered through the CLI's
#             in-process C backend) — verifies the CLI and libgmp and renders
#             one sample, so an ERR column can be told apart from a missing
#             toolchain. An external worktree renderer (shir_render, for
#             `C_RENDER=`) is reported when one exists; it is NOT required:
#             `--target shir | shir_render` loses type verdicts and
#             miscompiles, while the CLI path is what harness/c_gate_main.sh
#             exercises.
#   frontends the `frontends` submodule (§9's PY_BENCH harness lives in
#             sh2perl/frontends/py-sh-go/profile_example). Uses
#             `git submodule update --init`; falls back to a plain clone of
#             the superproject's URL when the pinned commit is no longer on
#             the remote (which is the state here — see the step's output).
#   shellbench the corpus §6 parses (/tmp/shellbench).
#
# NOT installed (deliberate):
#   * system packages (apt) — no passwordless sudo on this box; see
#     `request_root` in the workspace if you want them (tcc, glslangValidator,
#     go, zig).
#   * glslangValidator / Vulkan — only the GPU columns need it, and those
#     already SKIP with a reason (bench-opt.sh).
#
# Usage:  harness/install-bench-toolchain.sh [--all|--node|--bench-c|--frontends|--shellbench]
#         harness/install-bench-toolchain.sh --check     # report only
#   Env:  NODE_VERSION (default: latest v22.x LTS line), PREFIX (~/.local),
#         SHELLBENCH_DIR (/tmp/shellbench), FRONTENDS_URL, C_WORKTREE
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"
SHELLBENCH_DIR="${SHELLBENCH_DIR:-/tmp/shellbench}"
FRONTENDS_URL="${FRONTENDS_URL:-https://github.com/gmatht/otranspiler-frontends.git}"
C_WORKTREE="${C_WORKTREE:-$ROOT/sh2perl/backends/c}"
NODE_VERSION="${NODE_VERSION:-}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

say()  { printf '\n== %s ==\n' "$*"; }
ok()   { printf '  PASS  %s\n' "$*"; }
skip() { printf '  SKIP  %s\n' "$*"; }
bad()  { printf '  FAIL  %s\n' "$*"; fails=$((fails+1)); }
have() { command -v "$1" >/dev/null 2>&1; }

# Is a no-password sudo available? Probed WITHOUT invoking sudo when it is
# absent, and every probe is bounded: a sudo that wants a password must not
# hang the installer (this script is also run from cron/agent contexts).
sudo_nopass() {
    have sudo || return 1
    timeout 5 sudo -n true >/dev/null 2>&1
}

ARCH="$(uname -m)"
case "$ARCH" in
    x86_64)  NODE_ARCH=x64 ;;
    aarch64) NODE_ARCH=arm64 ;;
    *)       NODE_ARCH="" ;;
esac

fails=0

# ─────────────────────────────────────────────────────────────────────
# 1. node
# ─────────────────────────────────────────────────────────────────────
node_version() { # echoes the version of the first node on PATH, or nothing
    have node || return 0
    node -v 2>/dev/null | head -1
}

install_node() {
    say "node (JS columns of §1/§4.1/§6/§8)"
    if have node; then
        ok "node already on PATH: $(node_version) at $(command -v node)"
        return 0
    fi
    if [ -x "$PREFIX/bin/node" ]; then
        export PATH="$PREFIX/bin:$PATH"
        ok "node already installed under $PREFIX/bin: $(node_version) (add $PREFIX/bin to PATH)"
        return 0
    fi
    if [ -z "$NODE_ARCH" ]; then
        bad "no official node build for $ARCH — install node by hand"
        return 1
    fi
    local ver="$NODE_VERSION"
    if [ -z "$ver" ]; then
        # the listing entry is "node-v22.x.y-linux-x64.tar.xz": strip the
        # leading "node-" AND the "v" so the URL below does not become "vv22".
        ver=$(curl -fsS --max-time 20 https://nodejs.org/dist/latest-v22.x/ \
              | grep -o 'node-v22\.[0-9.]*-linux-'"$NODE_ARCH"'\.tar\.xz' | head -1)
        ver="${ver#node-v}"; ver="${ver%-linux-*}"
    fi
    [ -n "$ver" ] || { bad "could not discover a v22.x release"; return 1; }
    local name="node-v${ver}-linux-${NODE_ARCH}"
    local url="https://nodejs.org/dist/v${ver}/${name}.tar.xz"
    printf '  fetching %s\n' "$url"
    curl -fsS --max-time 300 -o "$TMP/node.tar.xz" "$url" \
        || { bad "download failed: $url"; return 1; }
    # Verify against the published checksum rather than trusting the TLS alone.
    if curl -fsS --max-time 30 "https://nodejs.org/dist/v${ver}/SHASUMS256.txt" -o "$TMP/SHASUMS256.txt"; then
        local want got
        want=$(awk -v n="${name}.tar.xz" '$2 == n {print $1}' "$TMP/SHASUMS256.txt")
        got=$(sha256sum "$TMP/node.tar.xz" | awk '{print $1}')
        if [ -z "$want" ] || [ "$want" != "$got" ]; then
            bad "checksum mismatch for ${name}.tar.xz (want ${want:-?}, got $got)"; return 1
        fi
        printf '  sha256 ok (%s)\n' "${got:0:16}…"
    else
        printf '  warning: SHASUMS256.txt unavailable; TLS-only integrity\n'
    fi
    mkdir -p "$PREFIX"
    tar -xJf "$TMP/node.tar.xz" -C "$TMP" || { bad "extract failed"; return 1; }
    rm -rf "$PREFIX/$name"
    mv "$TMP/$name" "$PREFIX/$name" || { bad "move failed"; return 1; }
    mkdir -p "$PREFIX/bin"
    ln -sfn "$PREFIX/$name/bin/node" "$PREFIX/bin/node"
    [ -x "$PREFIX/$name/bin/npm" ] && ln -sfn "$PREFIX/$name/bin/npm" "$PREFIX/bin/npm"
    export PATH="$PREFIX/bin:$PATH"
    local v; v=$(node_version)
    if [ -n "$v" ]; then
        ok "node $v at $(command -v node)"
        case ":$PATH:" in
            *":$PREFIX/bin:"*) : ;;
            *) printf '        (add %s/bin to PATH for future shells)\n' "$PREFIX" ;;
        esac
    else
        bad "node installed but not runnable"
    fi
}

# ─────────────────────────────────────────────────────────────────────
# 2. the C renderer
# ─────────────────────────────────────────────────────────────────────
# Candidates, in the order the harnesses try them: shir_render --target=c -
# (what setup_backends.sh's gate probes), then the older c-specific binaries.
c_renderer() {
    local d="$1"
    for b in shir_render c_backend shir_to_c; do
        [ -x "$d/$b" ] && { echo "$d/$b"; return 0; }
    done
    return 1
}

probe_c_renderer() { # binary -> 0 when it renders the sample to non-empty C
    local bin="$1" out
    out=$("$ROOT/otranspilerl/target/debug/otranspilerl-cli" --target shir \
              "$ROOT/sh2perl/examples/sync-direct-call-await.sh" 2>/dev/null \
          | "${C_CLI:-$bin}" --target=c - 2>/dev/null)
    if [ -z "$out" ]; then
        out=$("$ROOT/otranspilerl/target/debug/otranspilerl-cli" --target shir \
                  "$ROOT/sh2perl/examples/sync-direct-call-await.sh" 2>/dev/null \
              | "$bin" 2>/dev/null)
    fi
    [ -n "$out" ] && printf '%s' "$out" | grep -q 'int main'
}

install_bench_c() {
    say "C renderer for bench.sh (the shellbench C column)"
    # bench.sh's C column renders through the CLI's own in-process backend
    # (`--target c`, the renderer harness/c_gate_main.sh exercises) and links
    # -lgmp -lm. It does NOT need a backend/c worktree; it needs the CLI and
    # the two libraries. An external worktree binary is only an override
    # ($C_RENDER), and the renderer it must provide is shir_render --target=c.
    if [ ! -x "$ROOT/otranspilerl/target/debug/otranspilerl-cli" ]; then
        bad "build the A1 emitter first: (cd otranspilerl && cargo build --bin otranspilerl-cli)"
        return 1
    fi
    # gmp headers, not just the runtime .so: the C backend emits mpz_*.
    if printf '#include <gmp.h>\nint main(void){mpz_t z; mpz_init(z); mpz_clear(z); return 0;}\n' \
         | cc -x c - -o "$TMP/gmp_probe" -lgmp -lm 2>/dev/null; then
        ok "gmp present (cc -lgmp compiles)"
    else
        bad "libgmp headers/lib missing — apt: libgmp-dev (needs root; see request_root)"
        return 1
    fi
    local sample="$ROOT/sh2perl/examples/sync-direct-call-await.sh" c
    c=$("$ROOT/otranspilerl/target/debug/otranspilerl-cli" --target c "$sample" 2>/dev/null)
    if [ -z "$c" ]; then
        bad "the CLI emitted no C for $sample"
        return 1
    fi
    if printf '%s\n' "$c" | cc -x c - -o "$TMP/probe" -lgmp -lm 2>/dev/null \
       && "$TMP/probe" >/dev/null 2>&1; then
        ok "CLI --target c renders and compiles (§6 C column available)"
    else
        bad "CLI --target c output did not compile+run"
        return 1
    fi
    # The shellbench benches use a different corpus (shellbench's own
    # samples), several of which the C backend does not compile yet (e.g.
    # `assign:positional params`, `string length`). Say so, and say it is a
    # backend gap: an external shir_render would not fix it (verified:
    # `--target shir | shir_render` loses type verdicts and miscompiles).
    printf '  note: benches the C backend cannot compile yet print ERR (docs/BASH_BENCH.md §6).\n'
    local bin
    if bin=$(c_renderer "$C_WORKTREE/target/debug"); then
        printf '  note: an external renderer also exists ($C_RENDER=%s)\n' "$bin"
    fi
}

# ─────────────────────────────────────────────────────────────────────
# 3. shellbench corpus
# ─────────────────────────────────────────────────────────────────────
install_shellbench() {
    say "shellbench corpus (§6)"
    if [ -d "$SHELLBENCH_DIR/sample" ] && ls "$SHELLBENCH_DIR"/sample/*.sh >/dev/null 2>&1; then
        ok "corpus present: $SHELLBENCH_DIR ($(ls "$SHELLBENCH_DIR"/sample/*.sh | wc -l) samples)"
        return 0
    fi
    rm -rf "$TMP/shellbench"
    if ! timeout 300 git clone --depth 1 https://github.com/shellspec/shellbench.git "$TMP/shellbench" >/dev/null 2>&1; then
        bad "git clone of shellbench failed (offline?)"; return 1
    fi
    mkdir -p "$(dirname "$SHELLBENCH_DIR")"
    rm -rf "$SHELLBENCH_DIR"
    mv "$TMP/shellbench" "$SHELLBENCH_DIR" || { bad "install to $SHELLBENCH_DIR failed"; return 1; }
    if ls "$SHELLBENCH_DIR"/sample/*.sh >/dev/null 2>&1; then
        ok "corpus installed: $SHELLBENCH_DIR ($(ls "$SHELLBENCH_DIR"/sample/*.sh | wc -l) samples)"
    else
        bad "$SHELLBENCH_DIR has no sample/*.sh"; return 1
    fi
}

# ─────────────────────────────────────────────────────────────────────
# 4. frontends submodule (the Python frontend benchmark, §9)
# ─────────────────────────────────────────────────────────────────────
install_frontends() {
    say "frontends submodule (§9, PY_BENCH)"
    local sub="$ROOT/sh2perl"
    local dir="$sub/frontends"
    if [ -n "$(ls -A "$dir" 2>/dev/null)" ]; then
        if [ -d "$dir/py-sh-go/profile_example" ]; then
            ok "frontends present with py-sh-go/profile_example: $dir"
        else
            printf '  note: %s is populated but has no py-sh-go/profile_example\n' "$dir"
            ok "frontends present: $dir"
        fi
        return 0
    fi
    printf '  git submodule update --init frontends\n'
    if timeout 600 git -C "$sub" submodule update --init frontends >>"$TMP/fe.log" 2>&1; then
        ok "submodule initialised from the pinned commit"
        return 0
    fi
    local pin
    pin=$(git -C "$sub" ls-tree HEAD frontends 2>/dev/null | awk '{print $3}')
    printf '  submodule update failed (pin %s)\n' "${pin:-?}"
    if timeout 30 git ls-remote "$FRONTENDS_URL" "$pin" 2>/dev/null | grep -q .; then
        bad "pin $pin exists on the remote but the update failed — check the log above"
        return 1
    fi
    printf '  pin %s is NOT on the remote (the superproject pins a commit the\n' "${pin:-?}"
    printf '  frontends repo no longer serves). Falling back to a plain clone.\n'
    if timeout 300 git clone --depth 1 "$FRONTENDS_URL" "$TMP/fe" >>"$TMP/fe.log" 2>&1; then
        rcode=$(git -C "$TMP/fe" rev-parse --short HEAD)
        rm -rf "$dir"; mkdir -p "$(dirname "$dir")"
        if mv "$TMP/fe" "$dir" && [ -n "$(ls -A "$dir")" ]; then
            printf '  note: cloned HEAD (%s), NOT the pinned %s — the pinned\n' "$rcode" "${pin:0:12}"
            printf '        contents are unavailable; record which you benchmarked.\n'
            if [ -d "$dir/py-sh-go/profile_example" ]; then
                ok "frontends cloned at $rcode with py-sh-go/profile_example"
            else
                ok "frontends cloned at $rcode"
            fi
            return 0
        fi
    fi
    bad "could not provide frontends (submodule broken; clone failed)"
}

# ─────────────────────────────────────────────────────────────────────
# 5. report-only
# ─────────────────────────────────────────────────────────────────────
report() {
    say "docs/BASH_BENCH.md toolchain status"
    if have node; then
        ok "node $(node_version)"
    elif [ -x "$PREFIX/bin/node" ]; then
        ok "node $("$PREFIX/bin/node" -v) (not on PATH)"
    else
        skip "node — run: $0 --node"
    fi
    # the C column needs the CLI's --target c + libgmp, not a worktree binary
    if [ -x "$ROOT/otranspilerl/target/debug/otranspilerl-cli" ] \
       && printf '#include <gmp.h>\nint main(void){mpz_t z; mpz_init(z); mpz_clear(z); return 0;}\n' \
            | cc -x c - -o "$TMP/gmp_probe" -lgmp -lm 2>/dev/null; then
        local bin
        if bin=$(c_renderer "$C_WORKTREE/target/debug"); then
            ok "CLI --target c + libgmp (external renderer also present: $bin)"
        else
            ok "CLI --target c + libgmp"
        fi
    else
        skip "C column toolchain (CLI --target c and/or libgmp) — run: $0 --bench-c"
    fi
    [ -d "$ROOT/sh2perl/frontends/py-sh-go" ] && ok "frontends" || skip "frontends — run: $0 --frontends"
    [ -d "$SHELLBENCH_DIR/sample" ] && ok "shellbench $SHELLBENCH_DIR" || skip "shellbench — run: $0 --shellbench"
    have tcc          && ok "tcc"          || skip "tcc (apt; needs root)"
    have glslangValidator && ok "glslangValidator" || skip "glslangValidator (apt; Vulkan legs already SKIP)"
    have go           && ok "go"           || skip "go (frontend benchmark only)"
    have zig          && ok "zig"          || skip "zig (frontend benchmark only)"
    have cython       && ok "cython"       || skip "cython (PY_BENCH §5)"
    printf '\n  node/JS, the C column, frontends and shellbench are the four pieces\n  docs/BASH_BENCH.md calls out as unverified without them (section 14).\n'
}

WHAT="${1:-}"
case "$WHAT" in
    ""|--all)    install_node; install_bench_c; install_shellbench; install_frontends ;;
    --node)      install_node ;;
    --bench-c|--c) install_bench_c ;;
    --shellbench) install_shellbench ;;
    --frontends) install_frontends ;;
    --check)     report ;;
    -h|--help)   sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "unknown option $WHAT (see --help)" >&2; exit 2 ;;
esac

if [ "$WHAT" != "--check" ]; then
    say "summary"
    if [ "$fails" -eq 0 ]; then
        printf '  all requested steps installed or already present\n'
    else
        printf '  %d step(s) failed — see the FAIL lines above\n' "$fails"
    fi
    printf '  re-run docs/BASH_BENCH.md §13 to exercise the new columns.\n'
fi
exit $(( fails > 0 ))
