#!/bin/bash
# harness/remote-sync.sh — mirror the parts of this workspace that a BACKEND
# GATE needs onto a remote build box (default: the `nuc-i5` at 192.168.1.117,
# 12 cores / 15 GB — this box's java/zig gates cannot finish a 654-file pass
# between other workers' builds, and the remote box is idle).
#
# WHY NOT `git clone`: both backend worktrees carry UNCOMMITTED renderer work
# (that is the whole point of a backend branch), and the remote has no GitHub
# deploy key. A direct rsync of the live tree ships the working copy exactly
# as the local gate would see it.
#
# WHAT IS COPIED (the gate's actual inputs + the two backends):
#   otranspilerl/            the CLI crate (core A1 emitter)
#   sh2perl/{src,Cargo.toml,Cargo.lock,rust-toolchain,examples,runtime,frontends}
#   sh2perl/backends/{java,zig}/   the two worktrees (renderer + their src/)
#   harness/                 kill-session.sh, build-lock.sh, this script
# NOT copied: any target/ (each backend's own deps are NOT shared across
# worktrees — they diverge in src/ — so the remote builds its own), .git/
# (history is not needed to build or gate), corpus logs, scratch.
#
#   harness/remote-sync.sh [user@host] [dest]
# Idempotent: --delete only inside the managed subdirs.
set -euo pipefail
HOST="${1:-192.168.1.117}"
DEST="${2:-/root/sh2loop}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
R="ssh -o BatchMode=yes $HOST"
# `-L` follows the LOCAL target symlinks (several crates point target/ at a
# shared dir); without it rsync ships a BROKEN absolute symlink and cargo
# dies with "Not a directory". `--exclude target/` then drops what -L
# materialises inside the transfer.
X=(-L --exclude 'target/' --exclude '.git/' --exclude '*.log'
   --exclude 'cache/' --exclude '.rt_metric.tsv' --exclude '__pycache__/')

$R "mkdir -p '$DEST/sh2perl/backends' '$DEST/harness'"

rsync -a "${X[@]}" "$ROOT/otranspilerl/"            "$HOST:$DEST/otranspilerl/"
rsync -a "${X[@]}" --exclude 'fail' "$ROOT/harness/"                 "$HOST:$DEST/harness/"

# the sh2perl core: select top-level entries explicitly (the submodule root
# has 21 GB of noise: crash logs, scratch dirs, nested worktrees)
for d in src examples runtime frontends backends/c core-requests docs; do
  [ -e "$ROOT/sh2perl/$d" ] || continue
  [ "$d" = "backends/c" ] && continue
  rsync -a "${X[@]}" "$ROOT/sh2perl/$d/" "$HOST:$DEST/sh2perl/$d/"
done
for f in Cargo.toml Cargo.lock rust-toolchain rust-toolchain.toml build.rs AGENTS.md; do
  [ -e "$ROOT/sh2perl/$f" ] && rsync -a "$ROOT/sh2perl/$f" "$HOST:$DEST/sh2perl/$f"
done

# the two backend worktrees under test
for b in java zig; do
  rsync -a "${X[@]}" --exclude 'fail' "$ROOT/sh2perl/backends/$b/" "$HOST:$DEST/sh2perl/backends/$b/"
done

echo "synced $ROOT -> $HOST:$DEST"
