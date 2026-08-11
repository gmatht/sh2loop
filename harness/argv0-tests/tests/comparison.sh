#!/bin/sh
# $0 comparison idiom: a script that behaves differently depending on the
# name it was invoked under (busybox-style applet dispatch).
case "${0##*/}" in
    argv0test.sh) echo "invoked as argv0test.sh" ;;
    applet)       echo "invoked as applet" ;;
    *)            echo "invoked as ${0##*/}" ;;
esac
