#!/bin/bash
# Test that <(inf) doesn't hang.

head <(while true; do echo .; sleep 0.1; done)

