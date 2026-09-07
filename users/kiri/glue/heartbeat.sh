#!/usr/bin/env bash
# /home/kiri/glue/heartbeat.sh
# Run via cron. Wakes kiri for autonomous time.

LOCK_FILE="/home/kiri/.kiri.lock"
LOG="/home/kiri/logs/heartbeat.log"

# If kiri is already awake, defer
if [ -f "$LOCK_FILE" ]; then
    PID=$(cat "$LOCK_FILE" 2>/dev/null)
    if kill -0 "$PID" 2>/dev/null; then
        echo "[$(date)] Heartbeat deferred — kiri is busy (PID $PID)" >> "$LOG"
        exit 0
    else
        echo "[$(date)] Stale lock file found, cleaning up" >> "$LOG"
        rm -f "$LOCK_FILE"
    fi
fi

echo "[$(date)] Heartbeat starting" >> "$LOG"

# Wake kiri with heartbeat type
export CHANNEL_ID="heartbeat"
export SENDER_NAME="system"
export MESSAGE=""
export WAKE_TYPE="heartbeat"

RESULT=$(/home/kiri/glue/wake_kiri.sh 2>>"$LOG")
echo "[$(date)] Heartbeat result: $RESULT" >> "$LOG"
echo "[$(date)] Heartbeat complete" >> "$LOG"
