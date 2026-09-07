#!/usr/bin/env bash
# /home/kiri/glue/send_telegram.sh
# Usage: send_telegram.sh <chat_id> "message text"
# Kiri can call this herself during any session.

source /home/kiri/.env

CHAT_ID="$1"
TEXT="$2"

if [ -z "$CHAT_ID" ] || [ -z "$TEXT" ]; then
    echo "Usage: send_telegram.sh <chat_id> \"message text\"" >&2
    exit 1
fi

API="https://api.telegram.org/bot${KIRI_BOT_TOKEN}"

# Send typing indicator
curl -s -X POST "${API}/sendChatAction" \
    -d chat_id="$CHAT_ID" \
    -d action="typing" > /dev/null 2>&1

# Handle message splitting (Telegram max is 4096 chars)
# Split on newlines where possible, falling back to hard split
while [ ${#TEXT} -gt 0 ]; do
    if [ ${#TEXT} -le 4096 ]; then
        CHUNK="$TEXT"
        TEXT=""
    else
        # Try to split at a newline before 4096
        CHUNK="${TEXT:0:4096}"
        LAST_NEWLINE=$(echo "$CHUNK" | grep -ob $'\n' | tail -1 | cut -d: -f1)
        if [ -n "$LAST_NEWLINE" ] && [ "$LAST_NEWLINE" -gt 2048 ]; then
            CHUNK="${TEXT:0:$LAST_NEWLINE}"
            TEXT="${TEXT:$((LAST_NEWLINE+1))}"
        else
            TEXT="${TEXT:4096}"
        fi
    fi

    curl -s -X POST "${API}/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="$CHUNK" \
        -d parse_mode="Markdown" > /dev/null 2>&1

    # Small delay between chunks
    if [ ${#TEXT} -gt 0 ]; then
        sleep 0.5
    fi
done
