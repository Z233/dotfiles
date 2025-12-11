#!/usr/bin/env bash
#
# Codex Smart Monitor
# Detects codex completion by looking for explicit completion markers
# Automatically retries on stream disconnection errors
#
# Usage: monitor-codex.sh <tmux-session-name> [max-iterations]
#
# Example: monitor-codex.sh codex-20251207-101435 180

set -euo pipefail

SESSION_NAME="${1:-}"
MAX_ITERATIONS="${2:-360}"  # Default: 360 iterations × 2 sec = 12 minutes

if [ -z "$SESSION_NAME" ]; then
    echo "Usage: $0 <tmux-session-name> [max-iterations]"
    exit 1
fi

echo "Monitoring codex in session: $SESSION_NAME"
echo "Max duration: $((MAX_ITERATIONS * 2 / 60)) minutes"
echo

ERROR_RETRY_COUNT=0
MAX_ERROR_RETRIES=3
LAST_LINE_COUNT=0
LAST_STATUS=""

# Helper function to print status with smart line management
print_status() {
    local status="$1"

    if [ "$status" = "$LAST_STATUS" ]; then
        # Same status - overwrite line
        printf "\r%-100s" "$status"
    else
        # Status changed - new line
        if [ -n "$LAST_STATUS" ]; then
            echo ""  # Complete the previous line
        fi
        printf "%s" "$status"
        LAST_STATUS="$status"
    fi
}

for i in $(seq 1 "$MAX_ITERATIONS"); do
    # Check if session still exists
    if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo ""  # Complete any in-progress line
        echo "✓ Codex completed (session closed)"
        break
    fi

    # Capture full output to analyze
    FULL_OUTPUT=$(tmux capture-pane -t "$SESSION_NAME" -p -S -500 2>/dev/null)

    # Get current line count to detect if output is being produced
    CURRENT_LINE_COUNT=$(echo "$FULL_OUTPUT" | wc -l | tr -d ' ')

    # Capture last 30 lines for detailed checks
    CURRENT_OUTPUT=$(echo "$FULL_OUTPUT" | tail -30)

    # Check for stream disconnection errors
    if echo "$CURRENT_OUTPUT" | grep -qE "ERROR:.*stream (disconnected|closed)|stream closed before"; then
        ERROR_RETRY_COUNT=$((ERROR_RETRY_COUNT + 1))

        if [ $ERROR_RETRY_COUNT -le $MAX_ERROR_RETRIES ]; then
            echo ""  # Complete any in-progress line
            echo "⚠️  Stream error detected (retry $ERROR_RETRY_COUNT/$MAX_ERROR_RETRIES)"
            echo "→ Sending 'Continue' to resume..."

            # Send "Continue" to the session to resume codex
            tmux send-keys -t "$SESSION_NAME" "Continue" Enter

            # Reset status tracking and wait for reconnection
            LAST_STATUS=""
            LAST_LINE_COUNT=0
            sleep 5
            continue
        else
            echo ""  # Complete any in-progress line
            echo "❌ Too many stream errors ($MAX_ERROR_RETRIES retries exhausted)"
            echo
            echo "=== Final Output (with errors) ==="
            echo "$FULL_OUTPUT" | tail -200
            exit 1
        fi
    fi

    # Check for definitive completion markers (but NOT if there was an error)
    if echo "$CURRENT_OUTPUT" | grep -qE "^tokens used$" && \
       ! echo "$CURRENT_OUTPUT" | grep -qE "ERROR:.*stream"; then
        echo ""  # Complete any in-progress line
        echo "✓ Codex completed successfully (found completion marker)"
        echo
        echo "=== Final Output ==="
        echo "$FULL_OUTPUT" | tail -200
        exit 0
    fi

    # Show progress based on what's happening
    if echo "$CURRENT_OUTPUT" | grep -qE "^thinking$"; then
        print_status "🤔 Codex thinking..."
    elif echo "$CURRENT_OUTPUT" | grep -qE "^exec$"; then
        print_status "⚙️ Codex executing command..."
    elif echo "$CURRENT_OUTPUT" | grep -qE "^codex$"; then
        print_status "💬 Codex responding..."
    elif [ "$CURRENT_LINE_COUNT" -gt "$LAST_LINE_COUNT" ]; then
        NEW_LINES=$((CURRENT_LINE_COUNT - LAST_LINE_COUNT))
        print_status "⏳ Codex running (output growing: +$NEW_LINES lines)"
    else
        # Output not growing - just show we're still monitoring
        print_status "⏳ Processing..."
    fi

    LAST_LINE_COUNT=$CURRENT_LINE_COUNT
    sleep 2
done

echo ""  # Complete any in-progress line
echo
echo "=== Final Output ==="
# Capture full output or indicate session is closed
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    tmux capture-pane -t "$SESSION_NAME" -p -S -200 2>/dev/null || true
else
    echo "(Session already closed)"
fi

if [ $i -eq "$MAX_ITERATIONS" ]; then
    echo
    echo "⚠️  Warning: Reached maximum monitoring duration"
    echo "Codex may still be running. Check session: tmux attach -t $SESSION_NAME"
fi

exit 0
