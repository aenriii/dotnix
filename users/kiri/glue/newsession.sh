#!/usr/bin/env bash
# /home/kiri/glue/newsession.sh
# Called by gateway when /newsession command is received.
# Args: $1 = chat_id

CHAT_ID="$1"
SESSION_FILE="/home/kiri/sessions/telegram_${CHAT_ID}.txt"

if [ ! -f "$SESSION_FILE" ] || [ ! -s "$SESSION_FILE" ]; then
    echo "no active session to close!"
    exit 0
fi

# Wake kiri with newsession type
export CHANNEL_ID="$CHAT_ID"
export SENDER_NAME="system"
export MESSAGE=""
export WAKE_TYPE="newsession"

RESULT=$(/home/kiri/glue/wake_kiri.sh)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    # Clear the session file (kiri already extracted what she needs)
    > "$SESSION_FILE"
fi

echo "$RESULT"
