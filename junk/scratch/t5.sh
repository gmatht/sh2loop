#!/bin/bash
f() {
  local x='$y'
  local a="$1"
  local b="${2:-def}"
  local c="${3//p/q}"
  echo "x=[$x] a=[$a] b=[$b] c=[$c]"
}
y=world
f A B pp
