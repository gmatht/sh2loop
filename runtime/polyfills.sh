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

# strSlice — s[lo:hi] (lo clamped >= 0; hi empty = to end; hi < lo = empty)
strSlice() {
  local s="$1" lo="$2" hi="$3"
  local l=0
  if (( lo > 0 )); then
    l=$lo
  fi
  if [[ -z "$hi" ]]; then
    echo "${s:$l}"
  else
    local len=$((hi - l))
    if (( len < 0 )); then
      len=0
    fi
    echo "${s:$l:$len}"
  fi
}

# strCompare — -1 if a<b, 0 if a==b, 1 if a>b (string order)
strCompare() {
  local a="$1" b="$2"
  if [[ "$a" == "$b" ]]; then
    echo "0"
  elif [[ "$a" < "$b" ]]; then
    echo "-1"
  else
    echo "1"
  fi
}

# strIndex — index of the FIRST occurrence of sep in s (-1 if absent)
strIndex() {
  local s="$1" sep="$2"
  if [[ "$s" == *"$sep"* ]]; then
    local pre="${s%%"$sep"*}"
    echo "${#pre}"
  else
    echo "-1"
  fi
}

# strLastIndex — index of the LAST occurrence of sep in s (-1 if absent)
strLastIndex() {
  local s="$1" sep="$2"
  if [[ "$s" == *"$sep"* ]]; then
    local pre="${s%"$sep"*}"
    echo "${#pre}"
  else
    echo "-1"
  fi
}

# strCount — NON-OVERLAPPING instances of sub in s (0 when sub empty)
strCount() {
  local s="$1"
  local sub="$2"
  if [[ -z "$sub" ]]; then
    echo "0"
    return
  fi
  local n=0
  local rest="$s"
  while [[ "$rest" == *"$sub"* ]]; do
    n=$((n + 1))
    rest="${rest#*"$sub"}"
  done
  echo "$n"
}

# strReplaceAll — replace ALL literal occurrences of old with neu
strReplaceAll() {
  local s="$1"
  local old="$2"
  local neu="$3"
  if [[ -z "$old" ]]; then
    echo "$s"
    return
  fi
  local out=""
  local rest="$s"
  while [[ "$rest" == *"$old"* ]]; do
    out="${out}${rest%%"$old"*}${neu}"
    rest="${rest#*"$old"}"
  done
  echo "${out}${rest}"
}

# strContainsAny — 1 iff s contains ANY character from cutset
strContainsAny() {
  local s="$1" cutset="$2"
  local i
  for ((i = 0; i < ${#cutset}; i++)); do
    local c="${cutset:$i:1}"
    if [[ "$s" == *"$c"* ]]; then
      echo "1"
      return
    fi
  done
  echo "0"
}

# joinSep — join the remaining args with sep
joinSep() {
  local sep="$1"
  shift
  local out="" first=1 item
  for item in "$@"; do
    if (( first == 1 )); then
      out="$item"
      first=0
    else
      out="${out}${sep}${item}"
    fi
  done
  echo "$out"
}

# globMatch — recursive glob matcher (lit, *, ?, [class], \escape).
# Echoes 1/0. No extglob (?(..) *(..) +(..) @(..) !(..)) yet.
globMatch() {
  local p="$1" v="$2"
  if [[ -z "$p" ]]; then
    if [[ -z "$v" ]]; then
      echo "1"
    else
      echo "0"
    fi
    return
  fi
  local c="${p:0:1}"
  case "$c" in
    \*)
      local r
      r=$(globMatch "${p:1}" "$v")
      if [[ "$r" == "1" ]]; then
        echo "1"
        return
      fi
      if [[ -n "$v" ]]; then
        r=$(globMatch "$p" "${v:1}")
        if [[ "$r" == "1" ]]; then
          echo "1"
          return
        fi
      fi
      echo "0"
      ;;
    \?)
      if [[ -n "$v" ]]; then
        local r
        r=$(globMatch "${p:1}" "${v:1}")
        if [[ "$r" == "1" ]]; then
          echo "1"
          return
        fi
      fi
      echo "0"
      ;;
    \[)
      local rest="${p:1}"
      local close="${rest%%]*}"
      if [[ "$close" != "$rest" ]]; then
        local clen=${#close}
        local cls="${rest:0:$clen}"
        local aoff=$((clen + 1))
        local after="${rest:$aoff}"
        local neg=0
        if [[ "${cls:0:1}" == '!' || "${cls:0:1}" == '^' ]]; then
          neg=1
          cls="${cls:1}"
        fi
        local ch="${v:0:1}"
        local matched=0
        if [[ -n "$ch" ]]; then
          if [[ "$cls" == *"$ch"* ]]; then
            matched=1
          fi
        fi
        if (( matched == 1 && neg == 0 )) || (( matched == 0 && neg == 1 )); then
          local r
          r=$(globMatch "$after" "${v:1}")
          if [[ "$r" == "1" ]]; then
            echo "1"
            return
          fi
        fi
      fi
      echo "0"
      ;;
    \\)
      local plen=${#p}
      if (( plen > 1 )); then
        local c2="${p:1:1}"
        if [[ "$c2" == "${v:0:1}" ]]; then
          local r
          r=$(globMatch "${p:2}" "${v:1}")
          if [[ "$r" == "1" ]]; then
            echo "1"
            return
          fi
        fi
      fi
      echo "0"
      ;;
    *)
      if [[ "$c" == "${v:0:1}" ]]; then
        local r
        r=$(globMatch "${p:1}" "${v:1}")
        if [[ "$r" == "1" ]]; then
          echo "1"
          return
        fi
      fi
      echo "0"
      ;;
  esac
}

# caseMatch — the first pattern matching value (echoes the pattern, or
# nothing). No nocasematch / pattern-`$()`-expansion yet.
caseMatch() {
  local value="$1"
  shift
  local p
  for p in "$@"; do
    local r
    r=$(globMatch "$p" "$value")
    if [[ "$r" == "1" ]]; then
      echo "$p"
      return
    fi
  done
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
strSlice hello 1 3
strSlice hello 0 5
strSlice hello 2
strSlice hello 5 2
strCompare a b
strCompare b a
strCompare a a
strIndex "hello world" "o"
strIndex "hello world" "xyz"
strIndex "hello" ""
strLastIndex "hello world" "o"
strLastIndex "hello" "xyz"
strCount "banana" "an"
strCount "aaaa" "aa"
strCount "hello" ""
strReplaceAll "a-b-c" "-" "+"
strReplaceAll "hello" "l" ""
strReplaceAll "abc" "" "x"
strContainsAny "hello" "xyz"
strContainsAny "hello" "ae"
strContainsAny "hello" ""
joinSep "," a b c
joinSep "-" x
joinSep ","
globMatch "*.txt" "file.txt"
globMatch "*.txt" "file.md"
globMatch "a?c" "abc"
globMatch "a?c" "ac"
globMatch "[abc]*" "apple"
globMatch "[abc]*" "zebra"
globMatch "[!a]*" "zebra"
globMatch "[!a]*" "apple"
globMatch "a\\*b" "a*b"
globMatch "a\\*b" "axb"
globMatch "*" ""
globMatch "" ""
globMatch "a*b*c" "aXbYc"
globMatch "**" "anything"
caseMatch "file.txt" "*.md" "*.txt"
caseMatch "file.md" "*.md" "*.txt"
caseMatch "hello" "h*" "*o"
caseMatch "hello" "x*" "y*"
