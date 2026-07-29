#!/bin/sh
# Test: env with variable assignment
if [ -x /lib/udev/vlan-network-interface ]; then
    env INTERFACE=$IFACE /lib/udev/vlan-network-interface
fi
