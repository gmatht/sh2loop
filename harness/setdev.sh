#!/usr/bin/env bash
# setdev.sh — toggle Perl's developer mode (warnings + verbose warnings).
# Sourced by sh2loop sessions; not by the corpus.
setdev() {
  local state="$1"
  case "$state" in
    on)  exec 3>&2 4>&2
         shopt -s expand_aliases
         PS4='+${BASH_SOURCE}:${LINENO}:${FUNCNAME[0]:-main}: '
         BASH_XTRACEFD=4
         set -T
         trap 'printf "%s\n" "${*:-LOG: $BASH_COMMAND}" >&3' DEBUG
         ;;
    off) trap - DEBUG
         unset BASH_XTRACEFD
         set +T
         shopt -u expand_aliases
         exec 3>&- 4>&-
         ;;
    *)   echo "usage: setdev on|off" >&2; return 2 ;;
  esac
}
