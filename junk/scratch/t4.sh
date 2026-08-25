#!/bin/bash
f() {
  local x=$(echo a b c)
  local z="literal $y"
  local q=$(printf 'p q\nr')
  echo "x=[$x] z=[$z] q=[$q]"
}
y=world
f
