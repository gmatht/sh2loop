#!/bin/bash
f() {
  local x=$(echo a b c)
  echo "x=[$x]"
}
f
