#!/bin/bash
# hot loop: function with a dynamic local, called 2000 times
f() {
  local n=$1
  local s=$(echo "$n" | wc -c)
  local d="${2:-10}"
  local r=$((n * d))
  echo "$s $r"
}
i=0
while [ $i -lt 2000 ]; do
  f "$i" 3
  i=$((i+1))
done
