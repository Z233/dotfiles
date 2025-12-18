#!/usr/bin/env bash
#
# Codex Smart Monitor
# Detects codex completion by looking for explicit completion markers
# Automatically retries on stream disconnection errors
#
# OUTPUT PERSISTENCE:
# - Writes output to /tmp/codex-monitor-$SESSION_NAME.out
# - This file can be read even if the script times out
#
# Usage: monitor-codex.sh <tmux-session-name>
#
# Example: monitor-codex.sh codex-20251207-101435

set -euo pipefail

SESSION_NAME="${1:-}"

if [ -z "$SESSION_NAME" ]; then
    echo "Usage: $0 <tmux-session-name>"
    exit 1
fi

# OUTPUT FILE - Always write to a persistent location
OUTPUT_FILE="/tmp/codex-monitor-${SESSION_NAME}.out"
LAST_CAPTURED_OUTPUT=""

# Cleanup and output function - called on any exit
output_and_cleanup() {
    local exit_code=$?
    if [ -n "$LAST_CAPTURED_OUTPUT" ]; then
        # Write to file first (most reliable)
        echo "$LAST_CAPTURED_OUTPUT" | tail -200 > "$OUTPUT_FILE"
        # Then output to stdout
        echo "$LAST_CAPTURED_OUTPUT" | tail -200
    fi
    exit $exit_code
}

# Trap signals to ensure output is captured
trap output_and_cleanup EXIT INT TERM

# Print output file location for retrieval
echo "OUTPUT_FILE=$OUTPUT_FILE"
echo "---"

ERROR_RETRY_COUNT=0
MAX_ERROR_RETRIES=3

while true; do
    # Check if session still exists
    if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        # Session is gone - output whatever we have and exit
        # The trap will handle outputting LAST_CAPTURED_OUTPUT
        exit 0
    fi

    # Capture full output to analyze
    FULL_OUTPUT=$(tmux capture-pane -t "$SESSION_NAME" -p -S -500 2>/dev/null || echo "")

    # Always update our last captured output
    if [ -n "$FULL_OUTPUT" ]; then
        LAST_CAPTURED_OUTPUT="$FULL_OUTPUT"
        # Continuously update the output file so it can be read if we timeout
        echo "$FULL_OUTPUT" | tail -200 > "$OUTPUT_FILE"
    fi

    # Capture last 30 lines for detailed checks
    CURRENT_OUTPUT=$(echo "$FULL_OUTPUT" | tail -30)

    # Check for stream disconnection errors
    if echo "$CURRENT_OUTPUT" | grep -qE "ERROR:.*stream (disconnected|closed)|stream closed before"; then
        ERROR_RETRY_COUNT=$((ERROR_RETRY_COUNT + 1))

        if [ $ERROR_RETRY_COUNT -le $MAX_ERROR_RETRIES ]; then
            # Send "Continue" to the session to resume codex
            tmux send-keys -t "$SESSION_NAME" "Continue" Enter
            sleep 5
            continue
        else
            # Max retries exceeded - trap will output
            exit 1
        fi
    fi

    # Check for definitive completion markers (but NOT if there was an error)
    if echo "$CURRENT_OUTPUT" | grep -qE "^tokens used$" && \
       ! echo "$CURRENT_OUTPUT" | grep -qE "ERROR:.*stream"; then
        # Success! Trap will output
        exit 0
    fi

    sleep 2
done
