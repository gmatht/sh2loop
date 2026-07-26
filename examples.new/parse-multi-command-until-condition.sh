#!/bin/bash
# until loop with multiple commands in the condition
until
	echo "waiting..."
	test -f /tmp/somefile
do
	sleep 1
done
