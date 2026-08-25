#!/usr/bin/env bash
# rotate_loop_logs.sh — archive loop worker logs to ai@10.42.0.1, then
# truncate the live files. Run from cron (see the crontab entry); safe
# alongside live workers: the .gz is a snapshot, and append-mode writers
# survive the truncation (the standard copytruncate race — the tail written
# between gzip's EOF and the truncate is a few seconds at most, and the
# next snapshot picks up the rest).
#
# Discipline:
#   1. compress FIRST into a persistent local buffer (log-archive/)
#   2. truncate the live file immediately after (small loss window)
#   3. rsync -ac (checksum-verified) to the archive host
#   4. prune: local buffer older than 7 days, remote snapshots older than
#      180 days — the audit trail is the remote; local is a grace buffer.
set -u

ROOT="${1:-/home/llm/sh2loop}"
ARCHIVE_HOST="ai@10.42.0.1"
ARCHIVE_DIR="/a/i/sh2loop-logs"
MIN_SIZE="$((200 * 1024 * 1024))"   # 200 MB — rotate anything this big
MAX_AGE_DAYS=7                      # ...or this old (with content)
LOCAL_KEEP_DAYS=7
REMOTE_KEEP_DAYS=180
LOG="$ROOT/rotate_loop_logs.log"

# one instance at a time (cron + manual runs)
exec 9>"$ROOT/.rotate_loop_logs.lock"
flock -n 9 || { echo "$(date) rotate: another instance running" >> "$LOG"; exit 0; }

mkdir -p "$ROOT/log-archive"
cd "$ROOT" || exit 1

# ── 1+2. compress → truncate ──────────────────────────────────────────
ts=$(date +%Y%m%d-%H%M%S)
rotated=0
for f in loop-*.log; do
    [ -f "$f" ] || continue
    size=$(stat -c %s "$f" 2>/dev/null || echo 0)
    [ "$size" -gt 0 ] || continue
    age_days=$(( ($(date +%s) - $(stat -c %Y "$f")) / 86400 ))
    if [ "$size" -ge "$MIN_SIZE" ] || [ "$age_days" -ge "$MAX_AGE_DAYS" ]; then
        if gzip -c "$f" > "$ROOT/log-archive/$f-$ts.gz" 2>/dev/null; then
            : > "$f"                       # copytruncate: snapshot is safe
            rotated=$((rotated+1))
            echo "$(date) rotated $f ($(numfmt --to=iec "$size"))" >> "$LOG"
        else
            echo "$(date) gzip FAILED for $f" >> "$LOG"
        fi
    fi
done

# ── 3. ship + verify ──────────────────────────────────────────────────
if [ "$rotated" -gt 0 ] || [ -n "$(ls -A "$ROOT"/log-archive 2>/dev/null)" ]; then
    if ! rsync -ac --timeout=300 "$ROOT/log-archive/" "$ARCHIVE_HOST:$ARCHIVE_DIR/" >> "$LOG" 2>&1; then
        echo "$(date) rotate: rsync FAILED — local buffer retained for retry" >> "$LOG"
        exit 1
    fi
fi

# ── 4. prune ──────────────────────────────────────────────────────────
find "$ROOT/log-archive" -name '*.gz' -mtime +"$LOCAL_KEEP_DAYS" -delete 2>/dev/null
timeout 120 ssh -o BatchMode=yes "$ARCHIVE_HOST" \
    "find '$ARCHIVE_DIR' -name '*.gz' -mtime +'$REMOTE_KEEP_DAYS' -delete 2>/dev/null" || true

echo "$(date) rotate: done ($rotated rotated)" >> "$LOG"
exit 0
