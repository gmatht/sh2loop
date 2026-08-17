#!/usr/bin/env bash
# batch-triage.sh — run a list of (frontend, example, backend) pairs with
# the sweep's exact verdict semantics, printing PASS/FAIL-BACKEND/etc.
# usage: batch-triage.sh [pairs-file]  (default: stdin lines "fe ex be")
set -u
ROOT=/home/llm/sh2loop
DEBASHC="$ROOT/sh2perl/target/debug/debashc"
RUNNER="$ROOT/harness/estree-runner.mjs"
TRIAGE="${TRIAGE:-$ROOT/triage}"
norm() { tr -d '\r' | sed 's/[[:space:]]*$//' | awk 'NF'; }

be_run() {  # be rendered-file -> executed output
  local be="$1" rendered="$2" tmp; tmp=$(mktemp -d "$TRIAGE/.bt.XXXXXX")
  case "$be" in
    sh) ( cd "$tmp" && bash "$rendered" ) < /dev/null 2>/dev/null;;
    perl) ( cd "$tmp" && perl "$rendered" ) < /dev/null 2>/dev/null;;
    c) ( cd "$tmp" && cp "$rendered" main.c && cc main.c -o t 2>/dev/null && timeout 15 ./t ) < /dev/null 2>/dev/null;;
    go) ( cd "$tmp" && cp "$rendered" main.go && timeout 15 go run main.go ) < /dev/null 2>/dev/null;;
    python) ( cd "$tmp" && python3 "$rendered" ) < /dev/null 2>/dev/null;;
    java) ( cd "$tmp" && cls=$(grep -oE 'public class [A-Za-z_][A-Za-z0-9_]*' "$rendered" | head -1 | awk '{print $3}') && cp "$rendered" "$cls.java" 2>/dev/null && timeout 15 javac "$cls.java" 2>/dev/null && timeout 15 java "$cls" ) < /dev/null 2>/dev/null;;
    rust) ( cd "$tmp" && rustc "$rendered" -o t 2>/dev/null && timeout 15 ./t ) < /dev/null 2>/dev/null;;
    js) ( cd "$tmp" && node "$rendered" ) < /dev/null 2>/dev/null;;
  esac
  rm -rf "$tmp"
}

fe_emit() {  # fe example -> A1 json on stdout
  local fe="$1" ex="$2" bin
  case "$fe" in
    sh2perl) "$DEBASHC" --shir "$ROOT/sh2perl/examples/$ex" --raw 2>/dev/null;;
    c-sh-go) bin="$ROOT/frontends/c-sh-go/c-sh-go";;
    cpp-sh-go) bin="$ROOT/frontends/cpp-sh-go/cpp-sh-go";;
    bat-sh-go) bin="$ROOT/frontends/bat-sh-go/bat-sh-go";;
    py-sh-go) bin="$ROOT/frontends/py-sh-go/py-sh-go";;
    perl-sh-go) bin="$ROOT/frontends/perl-sh-go/perl-sh-go";;
    posix-sh-go) bin="$ROOT/frontends/posix-sh-go/posix-sh-go";;
    zsh-sh-go) bin="$ROOT/frontends/zsh-sh-go/zsh-sh-go";;
    fish-sh-go) bin="$ROOT/frontends/fish-sh-go/fish-sh-go";;
    go-sh) bin="$ROOT/frontends/go-sh/go-sh";;
    powershell-sh-go) bin="$ROOT/frontends/powershell-sh-go/powershell-sh-go";;
    rust-frontend) bin="$ROOT/frontends/rust-frontend/target/debug/rust-frontend";;
    zig-sh-go) bin="$ROOT/frontends/zig-sh-go/zig-sh-go";;
  esac
  if [ -n "${bin:-}" ]; then
    local corpus="testdata"
    [ "$fe" = "cpp-sh-go" ] && corpus="testdata_cpp"
    "$bin" --shir "$ROOT/frontends/$fe/$corpus/$ex" --raw 2>/dev/null
  fi
}

fe_native() {  # fe example -> native output
  local fe="$1" ex="$2" tmp; tmp=$(mktemp -d "$TRIAGE/.bn.XXXXXX")
  case "$fe" in
    sh2perl|posix-sh-go) ( cd "$tmp" && timeout 20 bash "$ROOT/sh2perl/examples/$ex" ) < /dev/null 2>/dev/null;;
    zsh-sh-go) ( cd "$ROOT/frontends/zsh-sh-go" && timeout 20 zsh "$ex" ) < /dev/null 2>/dev/null;;
    fish-sh-go) ( cd "$ROOT/frontends/fish-sh-go" && timeout 20 fish "$ex" ) < /dev/null 2>/dev/null;;
    go-sh) if grep -q 'func main()' "$ROOT/frontends/go-sh/testdata/$ex"; then cp "$ROOT/frontends/go-sh/testdata/$ex" "$tmp/main.go"; else { printf 'package main\nimport "fmt"\nfunc main() {\n'; cat "$ROOT/frontends/go-sh/testdata/$ex"; printf '}\n'; } > "$tmp/main.go"; fi; ( cd "$tmp" && timeout 20 go run main.go ) < /dev/null 2>/dev/null;;
    py-sh-go) ( cd "$tmp" && timeout 20 python3 "$ROOT/frontends/py-sh-go/testdata/$ex" ) < /dev/null 2>/dev/null;;
    perl-sh-go) ( cd "$tmp" && timeout 20 perl "$ROOT/frontends/perl-sh-go/testdata/$ex" ) < /dev/null 2>/dev/null;;
    *) : ;;
  esac
  rm -rf "$tmp"
}

while read -r fe ex be; do
  [ -n "$fe" ] || continue
  a1=$(fe_emit "$fe" "$ex")
  if [ -z "$a1" ]; then echo "SKIP-EMIT $fe/$ex/$be"; continue; fi
  T=$(mktemp -d "$TRIAGE/.bp.XXXXXX")
  printf '%s' "$a1" > "$T/a1.json"
  # estree reference
  if ! "$DEBASHC" --shir-in-estree "$T/a1.json" > "$T/e.json" 2>/dev/null; then
    echo "SKIP-ESTREE-REF $fe/$ex/$be (render failed)"; rm -rf "$T"; continue
  fi
  src=""
  if [ "$fe" = "sh2perl" ]; then src="$ROOT/sh2perl/examples/$ex"; elif [ "$fe" = "cpp-sh-go" ]; then src="$ROOT/frontends/cpp-sh-go/testdata_cpp/$ex"; else src="$ROOT/frontends/$fe/testdata/$ex"; fi
  enorm=$(timeout 30 node "$RUNNER" "$T/e.json" --source "$src" 2>/dev/null | norm)
  if [ "${enorm:0:12}" = "__ESTREE_REF" ]; then
    echo "SKIP-ESTREE-REF $fe/$ex/$be (ref failed)"; rm -rf "$T"; continue
  fi
  nnorm=$(fe_native "$fe" "$ex" | norm)
  # bat has no native — estree IS the oracle
  [ -z "$nnorm" ] && nnorm="$enorm"
  # backend render
  case "$be" in
    js) flag=--shir-in-js;; perl) flag=--shir-in-perl;; sh) flag=--shir-in-sh;;
    c) flag=--shir-in-c;; go) flag=--shir-in-go;; python) flag=--shir-in-python;;
    java) flag=--shir-in-java;; rust) flag=--shir-in-rust;; zig) flag=--shir-in-zig;;
  esac
  if ! "$DEBASHC" "$flag" "$T/a1.json" > "$T/rendered" 2>"$T/render.err"; then
    err=$(head -c 120 "$T/render.err")
    echo "FAIL-BACKEND $fe/$ex/$be (render failed: $err)"
  elif head -c 120 "$T/rendered" | grep -qiE "refuse|unsupported"; then
    echo "SKIP-REFUSE $fe/$ex/$be ($(head -c 100 "$T/rendered"))"
  elif [ "$be" = "zig" ]; then
    echo "PASS-RENDER $fe/$ex/$be"
  else
    bnorm=$(be_run "$be" "$T/rendered" | norm)
    if [ "$bnorm" = "$nnorm" ]; then
      echo "PASS $fe/$ex/$be"
    elif [ "$enorm" = "$nnorm" ]; then
      echo "FAIL-BACKEND $fe/$ex/$be (estree matches native; $be differs)"
      if [ -f "$T/rendered" ]; then echo "  rendered-head: $(head -c 150 "$T/rendered" | tr '\n' '|')"; fi
      echo "  got: $(echo "$bnorm" | head -c 150 | tr '\n' '|')  want: $(echo "$nnorm" | head -c 150 | tr '\n' '|')"
    else
      echo "FAIL-FRONTEND $fe/$ex/$be (estree reference also mismatches)"
    fi
  fi
  rm -rf "$T"
done
