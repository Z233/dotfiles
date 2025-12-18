---
name: codex
description: Use when the user asks to run Codex CLI (codex exec, codex resume) or references OpenAI Codex for code analysis, refactoring, or automated editing
allowed-tools: Bash, BashOutput, Read, AskUserQuestion
---

# Codex Skill Guide

## Running a Task
1. Check for existing codex session first: Before starting a new task, check the current conversation context for any recent codex sessions:
   - Look for session names in the format `codex-YYYYMMDD-HHMMSS` mentioned in recent messages
   - If a session exists and is relevant to the current task, prefer resuming it instead of starting new
   - Only start a new session if no existing session is found in context or if the task is unrelated
2. Ask the user (via `AskUserQuestion`) which model to run (`gpt-5.1-codex-max` or `gpt-5.2`) AND which reasoning effort to use (`high`, `medium`, or `low`) in a **single prompt with two questions** (only when starting a new session - skip for resume).
3. Select the sandbox mode required for the task; default to `--sandbox=read-only` unless edits or network access are necessary.
4. Assemble the codex command with the appropriate options:
   - `-m, --model <MODEL>`
   - `--config model_reasoning_effort="<high|medium|low>"`
   - `--sandbox <read-only|workspace-write|danger-full-access>`
   - `--full-auto`
   - `-C, --cd <DIR>`
   - `--skip-git-repo-check`
5. Always use --skip-git-repo-check.
6. **Execute via tmux**:
   - Create a unique session name: `SESSION_NAME="codex-$(date +%Y%m%d-%H%M%S)"`
   - Run in detached tmux session: `tmux new-session -d -s "$SESSION_NAME" "codex exec [options] 2>&1; sleep 10"`
   - Use `sleep 10` to ensure output is fully flushed before session closes
   - Use the monitoring script: `~/.claude/skills/codex/scripts/monitor-codex.sh "$SESSION_NAME"`
   - The script automatically detects completion and captures final output
   - Users can attach anytime to view real-time output: `tmux attach -t $SESSION_NAME`
7. **Output handling**: Use `2>&1` to capture both stdout and stderr (including thinking tokens) in the tmux session.
8. **When resuming an existing session**: Use `codex exec --skip-git-repo-check resume --last` via stdin. When resuming don't use any configuration flags unless explicitly requested by the user e.g. if they specify the model or the reasoning effort when requesting to resume a session. Resume syntax in tmux: `tmux send-keys -t "$SESSION_NAME" "echo 'your prompt here' | codex exec --skip-git-repo-check resume --last 2>&1" Enter`. All flags must be inserted between exec and resume.
9. **Monitor with monitor-codex.sh**: After starting the tmux session, run `~/.claude/skills/codex/scripts/monitor-codex.sh "$SESSION_NAME"` to automatically monitor and detect completion. The script will display progress and capture final output when codex finishes.
10. **After Codex starts**, inform the user:
   - Session name and how to attach: `tmux attach -t codex-YYYYMMDD-HHMMSS`
   - How to detach: Press `Ctrl+B` then `D`
   - How to list sessions: `tmux list-sessions | grep codex-`
11. **After Codex completes**, inform the user: "You can resume this Codex session at any time by saying 'codex resume' or asking me to continue with additional analysis or changes."

### Quick Reference
| Use case | Sandbox mode | Execution pattern |
| --- | --- | --- |
| Check for existing session | N/A | Look for `codex-YYYYMMDD-HHMMSS` in conversation context |
| Read-only review or analysis | `read-only` | `SESSION_NAME="codex-$(date +%Y%m%d-%H%M%S)"; tmux new-session -d -s "$SESSION_NAME" "codex exec --sandbox read-only [options] 2>&1; sleep 10"` |
| Apply local edits | `workspace-write` | `SESSION_NAME="codex-$(date +%Y%m%d-%H%M%S)"; tmux new-session -d -s "$SESSION_NAME" "codex exec --sandbox workspace-write --full-auto [options] 2>&1; sleep 10"` |
| Permit network or broad access | `danger-full-access` | `SESSION_NAME="codex-$(date +%Y%m%d-%H%M%S)"; tmux new-session -d -s "$SESSION_NAME" "codex exec --sandbox danger-full-access --full-auto [options] 2>&1; sleep 10"` |
| Resume in existing session | Inherited from original | `tmux send-keys -t "$SESSION_NAME" "echo 'prompt' \| codex exec --skip-git-repo-check resume --last 2>&1" Enter` |
| Resume in new session | Inherited from original | `SESSION_NAME="codex-$(date +%Y%m%d-%H%M%S)"; tmux new-session -d -s "$SESSION_NAME" "echo 'prompt' \| codex exec --skip-git-repo-check resume --last 2>&1; sleep 10"` |
| Run from another directory | Match task needs | Add `-C <DIR>` to the codex command |
| Monitor execution | N/A | `~/.claude/skills/codex/scripts/monitor-codex.sh "$SESSION_NAME"` |
| Attach to view live | N/A | `tmux attach -t codex-YYYYMMDD-HHMMSS` |

### Monitoring Best Practices

**Using the monitor-codex.sh script:**

```bash
# Complete workflow example
SESSION_NAME="codex-$(date +%Y%m%d-%H%M%S)"

# Start codex in tmux
tmux new-session -d -s "$SESSION_NAME" "codex exec [options] 2>&1; sleep 10"

# Monitor with the script (blocks until completion)
~/.claude/skills/codex/scripts/monitor-codex.sh "$SESSION_NAME"
```

**Script features:**
- Blocks until codex completes (no timeout)
- Silent monitoring (no progress output)
- Outputs final result only on completion
- Auto-retry on stream disconnection errors (up to 3 retries)
- Writes output to `/tmp/codex-monitor-$SESSION_NAME.out` for reliable retrieval

### Output Retrieval

The monitor script writes output to `/tmp/codex-monitor-$SESSION_NAME.out` for reliable retrieval.

**If monitor script times out or stdout output is incomplete:**
```bash
cat "/tmp/codex-monitor-$SESSION_NAME.out"
```

**Cleanup after retrieval:**
```bash
rm -f "/tmp/codex-monitor-$SESSION_NAME.out"
```

**Manual monitoring (for debugging):**

If you need to check manually:
```bash
PANE_PID=$(tmux list-panes -t "$SESSION_NAME" -F "#{pane_pid}" | head -1)
pgrep -P "$PANE_PID" codex  # Returns PID if running, empty if done
```

## Following Up
- **Prefer session reuse**: Always check for existing codex sessions in conversation context before starting new ones (look for `codex-YYYYMMDD-HHMMSS` session names).
- After every `codex` command, immediately use `AskUserQuestion` to confirm next steps, collect clarifications, or decide whether to resume.
- **Benefits of session reuse:**
  - Maintains context from previous interactions
  - Saves token costs by reusing conversation history
  - Faster startup (no model/config selection needed)
  - Automatically uses the same model, reasoning effort, and sandbox mode
- **Resuming in tmux:**
  - If the original tmux session still exists, reuse it: `tmux send-keys -t "$SESSION_NAME" "echo 'new prompt' | codex exec --skip-git-repo-check resume --last 2>&1; sleep 3" Enter`
  - If session is gone or user wants a fresh session: Create new session with the resume command
  - Check active sessions: `tmux list-sessions 2>/dev/null | grep "^codex-"`
- **When to start a new session instead:**
  - Task is unrelated to previous session's context
  - User explicitly requests a fresh start
  - Different working directory or project
  - No resumable session exists
- Monitor output via `tmux capture-pane` and inform the user of the session name for manual attachment.

## Error Handling
- **Session creation failures:** If `tmux new-session` fails, capture the error and report to the user. Common issues include invalid session names or tmux server problems.
- **Session lost during resume:** If attempting to resume but the tmux session no longer exists, inform the user and offer to create a new session for the resume operation.
- **Stream disconnection errors:** The monitor script automatically detects stream errors (`ERROR: stream disconnected/closed`) and sends "Continue" to resume (up to 3 retries). If all retries fail, report the error to the user.
- **Hung processes:** If codex appears stuck, user can attach to check status or kill the session.
- Stop and report failures whenever `codex --version` or a `codex exec` command exits non-zero; request direction before retrying.
- Before you use high-impact flags (`--full-auto`, `--sandbox danger-full-access`, `--skip-git-repo-check`) ask the user for permission using AskUserQuestion unless it was already given.
- When output includes warnings or partial results, summarize them and ask how to adjust using `AskUserQuestion`.
- **Session cleanup reminder:** Periodically remind users they can clean up old sessions with `tmux kill-session -t codex-YYYYMMDD-HHMMSS` or list all sessions with `tmux list-sessions | grep codex-`.
