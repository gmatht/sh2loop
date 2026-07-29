#!/bin/sh
# Test: hostname with path prefix and -F flag
if [ -f "/etc/hostname" ]; then
    /bin/hostname -F /etc/hostname >/dev/null 2>&1
fi
