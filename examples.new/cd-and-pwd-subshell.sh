#!/bin/bash
# Test: cd && pwd inside $(...) command substitution
# This was generating qx{cd ... && pwd} which triggered check_qx
DIR="$(cd . && pwd)"
echo "$DIR"
