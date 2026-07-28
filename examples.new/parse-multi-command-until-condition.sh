#!/bin/bash
# until loop with multiple commands in the condition
until
	echo "waiting..."
	test -f /tmp/until_condition_somefile
do
	sleep 1
done
