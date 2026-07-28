#!/bin/bash
# many-assignments-complex.sh
#
# A script with many variable assignments (both simple and using command
# substitution).  Large numbers of assignments cause the generator to
# produce many "DEBUG: Processing Assignment command" lines, which adds
# stderr-write overhead when debug is enabled.  In the debug build this
# can push processing time over the 10-second timeout when multiple
# workers are running concurrently.
#
# This file is SAFE to run: it only reads /proc/uptime and echoes text.

A=1
B=2
C=3
D=4
E=5
F=6
G=7
H=8
I=9
J=10
K=11
L=12
M=13
N=14
O=15
P=16
Q=17
R=18
S=19
T=20
U=21
V=22
W=23
X=24
Y=25
Z=26

# Command substitutions
UPTIME=$(cut -d' ' -f1 /proc/uptime 2>/dev/null || echo 0)
LOAD=$(cut -d' ' -f1 /proc/loadavg 2>/dev/null || echo 0)

# String interpolation with variables
MSG="Values: $A $B $C $D $E $F $G $H $I $J $K $L $M $N $O $P $Q $R $S $T $U $V $W $X $Y $Z"
echo "$MSG"
echo "uptime=$UPTIME load=$LOAD"
