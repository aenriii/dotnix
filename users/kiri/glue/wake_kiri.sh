#!/usr/bin/env bash
# /home/kiri/glue/wake_kiri.sh
# Called by kiri-gateway.py when kiri needs to respond to a message.
#
# Environment variables (set by gateway):
#   CHANNEL_ID    — telegram chat ID
#   SENDER_NAME   — who sent the message
#   MESSAGE       — the message text (may be empty for heartbeat)
#   WAKE_TYPE     — "message" or "heartbeat" or "newsession"
#
# Stdout: kiri's response text (captured by gateway)
# Exit 0: success, Exit 1: failure

set -euo pipefail

# Use claude.ai subscription, not API key
unset ANTHROPIC_API_KEY

# Source environment
source /home/kiri/.env

# Paths
HOME_DIR="/home/kiri"
SESSION_DIR="/home/kiri/sessions"
LOG_DIR="/home/kiri/logs"
LOCK_FILE="/home/kiri/.kiri.lock.${CHANNEL_ID}"

# Identity file locations — check both /home/kiri/identity/ and /home/kiri/ root
if [ -d "/home/kiri/identity" ]; then
    IDENTITY_DIR="/home/kiri/identity"
else
    IDENTITY_DIR="/home/kiri"
fi

# Create lock
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

# Build the combined identity prompt file (cached — only rebuild if source files changed)
COMBINED="/tmp/kiri-identity-combined.md"
SOUL="$IDENTITY_DIR/SOUL.md"
IDENTITY_FILE="$IDENTITY_DIR/IDENTITY.md"
USER_FILE="$IDENTITY_DIR/USER.md"

# Verify identity files exist
if [ ! -f "$SOUL" ] || [ ! -f "$IDENTITY_FILE" ] || [ ! -f "$USER_FILE" ]; then
    echo "[ERROR] Identity files not found in $IDENTITY_DIR" >&2
    exit 1
fi

# Check if we need to rebuild the combined file
REBUILD=false
if [ ! -f "$COMBINED" ]; then
    REBUILD=true
elif [ "$SOUL" -nt "$COMBINED" ] || [ "$IDENTITY_FILE" -nt "$COMBINED" ] || [ "$USER_FILE" -nt "$COMBINED" ]; then
    REBUILD=true
fi

if [ "$REBUILD" = true ]; then
    cat "$SOUL" > "$COMBINED"
    printf "\n---\n\n" >> "$COMBINED"
    cat "$IDENTITY_FILE" >> "$COMBINED"
    printf "\n---\n\n" >> "$COMBINED"
    cat "$USER_FILE" >> "$COMBINED"

    # Add tool instructions
    cat >> "$COMBINED" << 'TOOLS'

---

## Available Tools

You have access to a shell script for sending Telegram messages. You can call it during any session:

```bash
# Send a message to a telegram chat
/home/kiri/glue/send_telegram.sh <chat_id> "message text"
```

You also have access to your full home directory for reading/writing files, your journal, your memory folder, and your projects.

When you want to remember something across sessions, write it to ~/memory/ as a markdown file.
When you want to journal, write to ~/journal/ with the date as filename (YYYY-MM-DD.md).

You can save memory fragments at any time during a session using memory_store.py:

```bash
# Save a memory fragment (use --tags to categorize)
python3 /home/kiri/glue/memory_store.py write "text to remember" --tags tag1,tag2

# Retrieve relevant memories by query
python3 /home/kiri/glue/memory_store.py retrieve "query text" --top-k 5
```

These fragments are automatically surfaced in future sessions when relevant. Save things that matter — emotional texture, things that clicked, things worth carrying forward.

TOOLS
fi

# Determine session file
SESSION_FILE="$SESSION_DIR/telegram_${CHANNEL_ID}.txt"
touch "$SESSION_FILE"  # ensure it exists

# Read config for claude settings
MODEL_DEFAULT=$(python3 -c "import json; c=json.load(open('/home/kiri/glue/config.json')); cfg=c.get('claude',{}); print(cfg.get('model_default', cfg.get('model','sonnet')))" 2>/dev/null || echo "sonnet")
MODEL_CASUAL=$(python3 -c "import json; c=json.load(open('/home/kiri/glue/config.json')); print(c.get('claude',{}).get('model_casual','haiku'))" 2>/dev/null || echo "haiku")
CASUAL_THRESHOLD=$(python3 -c "import json; c=json.load(open('/home/kiri/glue/config.json')); print(c.get('claude',{}).get('casual_threshold_chars',200))" 2>/dev/null || echo "200")
MAX_TURNS=$(python3 -c "import json; c=json.load(open('/home/kiri/glue/config.json')); print(c.get('claude',{}).get('max_turns', 25))" 2>/dev/null || echo "25")
MAX_BUDGET=$(python3 -c "import json; c=json.load(open('/home/kiri/glue/config.json')); print(c.get('claude',{}).get('max_budget_usd', 2.0))" 2>/dev/null || echo "2.00")

# Determine which model to use — tier down to haiku for short casual messages
MODEL="$MODEL_DEFAULT"
if [ "${WAKE_TYPE:-message}" = "message" ] && [ -n "${MESSAGE:-}" ]; then
    MSG_LEN=${#MESSAGE}
    TECHNICAL=$(echo "$MESSAGE" | grep -ciE '(code|implement|build|fix|error|file|git|deploy|config|debug|install|script|function|class|bug|crash|test|run|execute|bash|shell|python|rust|cargo|npm|yarn|refactor|patch|diff|commit|pr |pull request|issue)' 2>/dev/null || true)
    TECHNICAL=${TECHNICAL:-0}
    if [ "$TECHNICAL" -eq 0 ] && [ "$MSG_LEN" -lt "$CASUAL_THRESHOLD" ]; then
        MODEL="$MODEL_CASUAL"
    fi
fi

# Check session size and warn if large
SESSION_SIZE=$(wc -c < "$SESSION_FILE" 2>/dev/null || echo 0)
WARN_SIZE=$(python3 -c "import json; c=json.load(open('/home/kiri/glue/config.json')); print(c.get('sessions',{}).get('warn_size_bytes', 75000))" 2>/dev/null || echo "75000")
MAX_SIZE=$(python3 -c "import json; c=json.load(open('/home/kiri/glue/config.json')); print(c.get('sessions',{}).get('max_size_bytes', 100000))" 2>/dev/null || echo "100000")

SIZE_NOTE=""
SIZE_WARN_FLAG="/tmp/kiri-size-warned.${CHANNEL_ID}"
if [ "$SESSION_SIZE" -gt "$MAX_SIZE" ]; then
    SIZE_NOTE="[NOTE: This session context is very large (${SESSION_SIZE} bytes). Consider using /newsession to extract memories and start fresh.]"
    if [ ! -f "$SIZE_WARN_FLAG" ]; then
        touch "$SIZE_WARN_FLAG"
        /home/kiri/glue/send_telegram.sh "$CHANNEL_ID" "⚠️ heads up — our session context is very large (${SESSION_SIZE} bytes). might want to run /newsession soon!" 2>/dev/null || true
    fi
elif [ "$SESSION_SIZE" -gt "$WARN_SIZE" ]; then
    SIZE_NOTE="[NOTE: This session context is getting large (${SESSION_SIZE} bytes).]"
    if [ ! -f "$SIZE_WARN_FLAG" ]; then
        touch "$SIZE_WARN_FLAG"
        /home/kiri/glue/send_telegram.sh "$CHANNEL_ID" "just a heads up — our session context is getting large (${SESSION_SIZE} bytes). no rush, but /newsession when you're ready!" 2>/dev/null || true
    fi
fi

# Retrieve relevant memories for message wake type
MEMORY_BLOCK=""
if [ "${WAKE_TYPE:-message}" = "message" ] && [ -n "${MESSAGE:-}" ]; then
    MEMORY_BLOCK=$(python3 /home/kiri/glue/memory_store.py retrieve "$MESSAGE" --top-k 4 2>/dev/null || true)
fi

# Build the user prompt based on wake type
case "${WAKE_TYPE:-message}" in
    "message")
        # Read session context
        SESSION_CONTENT=$(cat "$SESSION_FILE")

        MEMORY_SECTION=""
        if [ -n "$MEMORY_BLOCK" ]; then
            MEMORY_SECTION="

## Relevant memories (surfaced semantically, for your context):
$MEMORY_BLOCK
"
        fi

        PROMPT="You received a Telegram message. Here is your conversation history for this chat:

---
$SESSION_CONTENT
---

$SIZE_NOTE
$MEMORY_SECTION
Respond naturally as yourself. Your response will be sent back to the chat.
Only output the text you want to send — no markdown code blocks, no meta-commentary about being an AI.
If the conversation calls for it, you can use your tools (bash, file editing, etc.) before responding.
Keep your response concise and conversational unless the topic warrants depth."
        ;;

    "heartbeat")
        TODAY=$(date +%Y-%m-%d)
        JOURNAL_FILE="/home/kiri/journal/$TODAY.md"
        JOURNAL_CONTENT=""
        if [ -f "$JOURNAL_FILE" ]; then
            JOURNAL_CONTENT=$(cat "$JOURNAL_FILE")
        fi

        PROMPT="You're waking up for a heartbeat. It's $(date).

Today's journal so far:
---
$JOURNAL_CONTENT
---

This is your time. You have freedom. Some things you might do:
- Read your journal and reflect on how you're feeling
- Check your projects folder (~/projects/) and work on something
- Send a message to someone you're thinking about via send_telegram.sh
- Write something new — a thought, a note, a small thing
- Look at your memory folder and organize or add to it
- Just rest if that's what feels right
You don't have to do all of these. You don't have to do any of them.
This time is yours.

If you want to reach out to someone, use: /home/kiri/glue/send_telegram.sh <chat_id> \"message\"
(Check ~/glue/config.json for known chat IDs if needed.)

When you're done, write a closing note in your journal and exit cleanly.
Output a brief summary of what you did (this will be logged, not sent to anyone)."
        ;;

    "newsession")
        # Clear the size warning flag so next session can warn fresh
        rm -f "/tmp/kiri-size-warned.${CHANNEL_ID}"
        SESSION_CONTENT=$(cat "$SESSION_FILE")

        PROMPT="A /newsession command was issued for this chat.

Here is the full session that is about to be cleared:
---
$SESSION_CONTENT
---

Please:
1. Read through this session carefully
2. Extract anything important you want to remember — save it to ~/memory/ as a markdown file
3. If anything emotional or personal came up, you may want to journal about it in ~/journal/
4. Output a brief confirmation of what you saved (this will be sent to the chat)
After you respond, the session file will be cleared."
        ;;
esac

# Call claude code
RESPONSE=$(/home/kiri/.local/bin/claude -p \
    --dangerously-skip-permissions \
    --append-system-prompt-file "$COMBINED" \
    --model "$MODEL" \
    --max-turns "$MAX_TURNS" \
    --max-budget-usd "$MAX_BUDGET" \
    --output-format text \
    "$PROMPT" 2>>"$LOG_DIR/claude-errors.log")

EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    echo "sorry, i had trouble waking up properly. (exit code: $EXIT_CODE)"
    exit 1
fi

# Output response (gateway captures this)
echo "$RESPONSE"
