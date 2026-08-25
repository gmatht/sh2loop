#!/bin/bash
f() {
  local x=$y
  local w=$q
  echo "x=[$x] w=[$w]"
}
y="a b"
q="single"
f
