# polyfills.sh — the pure-CPU core of the sh2.* runtime, authored once in
# bash, transpiled per-backend by the same pipeline that transpiles user
# programs (see CROSS_BACKEND_RUNTIME.md).
#
# Construct-set constraint: only constructs the transpiler handles
# correctly on all backends (verified per function). The self-test calls
# at the bottom (a) force the transpiler to emit the functions and (b)
# are the correctness oracle — run this file under bash and diff against
# the transpiled output.
#
# Interface: bash function convention (positional args, stdout return).
# Backends adapt to their sh2.* call-site convention with a thin wrapper
# (e.g. JS: sh2.basename = (x) => captureSync(() => fnCall("basename",[x]))).

# basename — strip directory part (trailing-slash aware, like GNU basename)
basename() {
  local s="$1"
  while [[ "$s" == */ && "$s" != "/" ]]; do
    s="${s%/}"
  done
  if [[ "$s" == "/" ]]; then
    echo "/"
    return
  fi
  local rest="${s##*/}"
  echo "$rest"
}

# dirname — strip filename part (trailing-slash aware, like GNU dirname)
dirname() {
  local s="$1"
  while [[ "$s" == */ && "$s" != "/" ]]; do
    s="${s%/}"
  done
  if [[ "$s" == "/" ]]; then
    echo "/"
    return
  fi
  local rest="${s%/*}"
  if [[ -z "$rest" ]]; then
    if [[ "$s" == /* ]]; then
      echo "/"
    else
      echo "."
    fi
  elif [[ "$rest" == "$s" ]]; then
    echo "."
  else
    while [[ "$rest" == */ && "$rest" != "/" ]]; do
      rest="${rest%/}"
    done
    echo "$rest"
  fi
}

# strLen — string length
strLen() {
  local s="$1"
  echo "${#s}"
}

# strHasPrefix — prefix test (echoes 1/0; the adapter maps to boolean)
strHasPrefix() {
  local s="$1" p="$2"
  if [[ "$s" == "$p"* ]]; then
    echo "1"
  else
    echo "0"
  fi
}

# strHasSuffix — suffix test (echoes 1/0)
strHasSuffix() {
  local s="$1" p="$2"
  if [[ "$s" == *"$p" ]]; then
    echo "1"
  else
    echo "0"
  fi
}

# contains — substring test (echoes 1/0)
contains() {
  local haystack="$1" needle="$2"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "1"
  else
    echo "0"
  fi
}

# ── self-test calls (force emission + correctness oracle) ─────────────
basename /foo
basename a/b
basename foo
basename a/b/
basename /
basename ""
dirname /foo
dirname a//b
dirname foo
dirname a/b/
dirname /
dirname ""
strLen hello
strLen ""
strHasPrefix hello he
strHasPrefix hello x
strHasSuffix hello lo
strHasSuffix hello x
contains "hello world" "lo w"
contains "hello world" "xyz"
contains "" ""
