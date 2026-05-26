#!/bin/bash

# Ralph Loop - Autonomous engineer relay
# See --help for usage.

set -e

# Track claude PID so we can kill it on Ctrl-C
CLAUDE_PID=""
cleanup() {
    echo -e "\n${RED}✗${NC} Interrupted"
    [ -n "$CLAUDE_PID" ] && kill "$CLAUDE_PID" 2>/dev/null
    exit 130
}
trap cleanup INT TERM

# ANSI colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
DIM='\033[2m'
NC='\033[0m' # No colour

print_help() {
    cat <<'EOF'
Ralph Loop — autonomous engineer relay.

Usage:
  ralph.sh [OPTIONS] [INSTRUCTIONS...]

Options:
  -h, --help              Show this help and exit.
  -n, --iterations N      Maximum loop iterations (default: 10).
      --harness NAME      Which CLI to spawn per iteration:
                            claude (default) — uses Claude Code with
                              stream-json output and pretty per-tool
                              formatting.
                            codex            — uses OpenAI Codex CLI
                              (`codex exec`), raw output streamed.
                            pi               — uses the pi coding
                              assistant (`pi --print`), raw output
                              streamed.

Arguments:
  INSTRUCTIONS            Free-text instructions appended to every harness
                          invocation in this run. All non-flag arguments
                          after options are joined with spaces and included
                          verbatim in the prompt. Use this to steer focus
                          ("only touch the CLI", "keep changes small", etc.)
                          without editing the ticket files.

Queue discovery:
  Ralph looks for a ticket folder in this order, in the current directory:
    docs/tickets/  docs/changes/  doc/changes/  doc/tickets/
  If none is found in the current directory, it scans IMMEDIATE
  subdirectories one level down for the same folder names. If exactly one
  subdirectory has a ticket folder, ralph cd's into that subdirectory and
  operates from there. If multiple subdirectories qualify, ralph lists
  them and exits — cd into the specific subproject yourself.

  Falls back to beads if `.beads/` is present and `bd` is on PATH.

Examples:
  ralph.sh                                 # 10 iterations, claude harness
  ralph.sh -n 100                          # 100 iterations
  ralph.sh 100                             # same (backwards-compat shorthand)
  ralph.sh focus on the auth code          # default iterations, focused steer
  ralph.sh -n 50 keep changes small        # both
  ralph.sh --harness codex                 # use OpenAI Codex CLI
  ralph.sh --harness pi -n 20              # use pi, 20 iterations
EOF
}

# ---- Parse args -----------------------------------------------------------

MAX_ITERATIONS=10
EXTRA_INSTRUCTIONS=""
HARNESS="claude"
POSITIONAL=()

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            print_help
            exit 0
            ;;
        -n|--iterations)
            if [ -z "${2:-}" ]; then
                echo -e "${RED}✗${NC} $1 requires a value" >&2
                exit 2
            fi
            MAX_ITERATIONS="$2"
            shift 2
            ;;
        --harness)
            if [ -z "${2:-}" ]; then
                echo -e "${RED}✗${NC} --harness requires a value (claude|codex|pi)" >&2
                exit 2
            fi
            HARNESS="$2"
            shift 2
            ;;
        --)
            shift
            POSITIONAL+=("$@")
            break
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

case "$HARNESS" in
    claude|codex|pi) ;;
    *)
        echo -e "${RED}✗${NC} unknown harness: $HARNESS (expected: claude, codex, pi)" >&2
        exit 2
        ;;
esac

if ! command -v "$HARNESS" &>/dev/null; then
    echo -e "${RED}✗${NC} harness binary '$HARNESS' not on PATH" >&2
    exit 2
fi

# Backwards-compat: a single purely-numeric positional arg is iterations.
if [ "${#POSITIONAL[@]}" -eq 1 ] && [[ "${POSITIONAL[0]}" =~ ^[0-9]+$ ]]; then
    MAX_ITERATIONS="${POSITIONAL[0]}"
elif [ "${#POSITIONAL[@]}" -gt 0 ]; then
    EXTRA_INSTRUCTIONS="${POSITIONAL[*]}"
fi

if ! [[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}✗${NC} iterations must be a positive integer (got: $MAX_ITERATIONS)" >&2
    exit 2
fi

# ---- Locate the ticket folder --------------------------------------------

TICKET_DIRS=("docs/tickets" "docs/changes" "doc/changes" "doc/tickets")

find_tickets_in() {
    # Echo the first matching ticket dir under $1, or nothing.
    local base="$1"
    local d
    for d in "${TICKET_DIRS[@]}"; do
        if [ -d "$base/$d" ]; then
            echo "$d"
            return 0
        fi
    done
    return 1
}

ITERATION=0
START_DIR="$PWD"
PROJECT_DIR="."   # relative to START_DIR; "." means tickets are at the top level

TICKETS_DIR=""
TICKETS_DIR=$(find_tickets_in ".") || true

if [ -z "$TICKETS_DIR" ]; then
    # Try one level down. Collect every subdirectory that has a ticket folder.
    # We DO NOT cd into the subdir — staying in $START_DIR keeps the harness's
    # trust boundary (claude --permission-mode acceptEdits, codex --add-dir)
    # rooted at the parent so sibling repos in a monorepo-style layout
    # (e.g. airskills/platform + airskills/cli) are both writable. The engineer
    # is told via the prompt where the project and ticket folder actually live.
    CANDIDATES=()
    for sub in */; do
        [ -d "$sub" ] || continue
        if found=$(find_tickets_in "${sub%/}"); then
            CANDIDATES+=("${sub%/}|$found")
        fi
    done

    if [ "${#CANDIDATES[@]}" -eq 1 ]; then
        IFS='|' read -r SUB FOUND <<<"${CANDIDATES[0]}"
        echo -e "${DIM}› No ticket folder in $PWD — engineer will focus on $SUB/${NC}"
        PROJECT_DIR="$SUB"
        TICKETS_DIR="$FOUND"
    elif [ "${#CANDIDATES[@]}" -gt 1 ]; then
        echo -e "${RED}✗${NC} Multiple subdirectories have ticket folders:" >&2
        for c in "${CANDIDATES[@]}"; do
            IFS='|' read -r SUB FOUND <<<"$c"
            echo "   - $SUB/$FOUND" >&2
        done
        echo "   cd into the specific subproject and re-run." >&2
        exit 1
    fi
fi

# Path to the ticket folder relative to $START_DIR (where we launch from).
if [ "$PROJECT_DIR" = "." ]; then
    TICKETS_PATH="$TICKETS_DIR"
else
    TICKETS_PATH="$PROJECT_DIR/$TICKETS_DIR"
fi

if [ -n "$TICKETS_DIR" ]; then
    MODE="files"
elif command -v bd &> /dev/null && [ -d ".beads" ]; then
    MODE="beads"
else
    echo -e "${RED}✗${NC} No queue found in $START_DIR or any immediate subdirectory."
    echo "   Looking for: ${TICKET_DIRS[*]}"
    echo "   Or a beads queue (.beads/ with bd installed)."
    exit 1
fi

echo -e "${CYAN}→${NC} Starting Ralph Loop in $PWD"
echo "   Max iterations: $MAX_ITERATIONS"
echo "   Harness:        $HARNESS"
if [ -n "$EXTRA_INSTRUCTIONS" ]; then
    echo -e "   Extra instructions: ${DIM}$EXTRA_INSTRUCTIONS${NC}"
fi
echo ""

WORK_STATUS_RE='^status:[[:space:]]*(todo|draft|pending|doing|in-progress)[[:space:]]*$'

count_pending() {
    grep -lE "$WORK_STATUS_RE" "$TICKETS_PATH"/*.md 2>/dev/null | wc -l | tr -d ' '
    return 0
}

list_pending() {
    local found=0
    for f in "$TICKETS_PATH"/*.md; do
        [ -f "$f" ] || continue
        status=$(awk -F': *' '/^status:/{print $2; exit}' "$f" | tr -d '[:space:]')
        case "$status" in
            todo|draft|pending|doing|in-progress)
                echo "   - $(basename "$f") ($status)"
                found=1
                ;;
        esac
    done
    if [ "$found" = "0" ]; then
        echo "   (none)"
    fi
    return 0
}

case "$MODE" in
    files)
        echo -e "${BLUE}▸${NC} Queue: $TICKETS_PATH/"
        echo -e "${BLUE}▸${NC} Pending tickets:"
        list_pending
        ;;
    beads)
        echo -e "${BLUE}▸${NC} Queue: beads"
        bd ready 2>/dev/null || echo "   No beads ready"
        ;;
esac
echo ""

while [ $ITERATION -lt $MAX_ITERATIONS ]; do
    # Check for dirty state - if dirty, skip fetch/pull (we're mid-work).
    # Use `git -C` so the check targets the project repo, not whatever lives
    # at $START_DIR (which may be a monorepo parent with no git of its own).
    if git -C "$PROJECT_DIR" diff --quiet && git -C "$PROJECT_DIR" diff --cached --quiet; then
        echo -e "${DIM}› Fetching latest changes...${NC}"
        git -C "$PROJECT_DIR" fetch --quiet
        git -C "$PROJECT_DIR" pull --rebase --quiet || true
        [ "$MODE" = "beads" ] && bd sync 2>/dev/null || true
    else
        echo -e "${YELLOW}› Dirty working tree detected - resuming previous work...${NC}"
    fi

    if [ "$MODE" = "files" ]; then
        WORK_COUNT=$(count_pending)
    else
        READY_COUNT=$(bd count --status open 2>/dev/null || echo "0")
        IN_PROGRESS=$(bd count --status in_progress 2>/dev/null || echo "0")
        WORK_COUNT=$((READY_COUNT + IN_PROGRESS))
    fi

    if [ "$WORK_COUNT" = "0" ]; then
        echo -e "${DIM}○ No work available. Waiting 20s for new work...${NC}"
        sleep 20
        continue
    fi

    ITERATION=$((ITERATION + 1))
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}▶${NC} Ralph iteration ${GREEN}$ITERATION${NC} of $MAX_ITERATIONS"
    echo "   Started: $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    echo -e "${BLUE}› Spawning $HARNESS engineer...${NC}"
    echo ""

    if [ "$MODE" = "files" ]; then
        if [ "$HARNESS" = "claude" ]; then
            # Slash command is a Claude Code feature only.
            PROMPT="/ralph"
        else
            # Inline a brief prompt for harnesses that don't load the skill.
            PROMPT="You are one engineer in a relay. Look at the ticket folder ($TICKETS_PATH/) for a markdown file with \`status: doing\` first (finish that); otherwise pick the best next file with \`status: todo\`. Read the SKILL.md at ~/.claude/skills/ralph/SKILL.md for the full protocol. Flip the file's status to \`doing\` while working, do the work TDD-style, run tests + lint, verify behaviour, flip to \`done\` with a \`completed:\` date, commit (single commit containing implementation + frontmatter flip), push, and exit. Complete ONE ticket and stop."
        fi
    else
        PROMPT="You are one engineer in a relay using beads as the queue. Run \`bd list --status in_progress\` first; if a bead is mid-flight, finish it. Otherwise pick the next from \`bd ready\` (skip beads labelled manual-testing), \`bd update <id> --status in_progress\`, do the work TDD-style, run tests + lint, verify behaviour, \`bd comments <id> add\` a closing note, \`bd close <id>\`, \`bd sync\`, commit, and exit. Complete ONE bead and stop."
    fi

    # Build the "additional instructions" block. Project location goes first
    # (when we're launched from a monorepo parent and the project lives in a
    # subdir), then any user-supplied steer.
    EXTRA_BLOCK=""
    if [ "$PROJECT_DIR" != "." ]; then
        EXTRA_BLOCK="Your cwd is the monorepo root \`$START_DIR\`. Tickets are in \`$TICKETS_PATH/\`. Run all git operations inside \`$PROJECT_DIR/\` (\`cd $PROJECT_DIR\` first, or \`git -C $PROJECT_DIR ...\`). Sibling directories at this level are separate repos — \`ls\` here to discover them; each needs its own commit/push if you edit it."
    fi
    if [ -n "$EXTRA_INSTRUCTIONS" ]; then
        if [ -n "$EXTRA_BLOCK" ]; then
            EXTRA_BLOCK="$EXTRA_BLOCK

$EXTRA_INSTRUCTIONS"
        else
            EXTRA_BLOCK="$EXTRA_INSTRUCTIONS"
        fi
    fi
    if [ -n "$EXTRA_BLOCK" ]; then
        PROMPT="$PROMPT

IMPORTANT additional instructions for this run (apply to every iteration):
$EXTRA_BLOCK"
    fi

    # Stream output with clean formatting.
    # Uses a FIFO so the harness runs as a tracked background process. This
    # lets the trap handler kill it on Ctrl-C (bash's `read` builtin blocks
    # signals but the cleanup trap fires between reads when the child dies).
    FIFO=$(mktemp -u /tmp/ralph-fifo-XXXXXX)
    mkfifo "$FIFO"

    # Capture stderr to a per-run logfile so harness failures aren't silent.
    # For text-streaming harnesses (codex, pi), also tee stderr to the terminal
    # so progress indicators are visible live — claude streams everything on
    # stdout via stream-json so its stderr stays silent.
    HARNESS_LOG="/tmp/ralph-${HARNESS}-$$.log"
    case "$HARNESS" in
        claude)
            claude --chrome --permission-mode acceptEdits --verbose --print "$PROMPT" --output-format stream-json > "$FIFO" 2>"$HARNESS_LOG" &
            ;;
        codex)
            # OpenAI Codex CLI — non-interactive `exec` mode with JSONL events.
            # --dangerously-bypass-approvals-and-sandbox matches the autonomy
            # model of `claude --permission-mode acceptEdits`. Also necessary
            # on hosts where bubblewrap can't open a network namespace
            # (`bwrap: loopback: Failed RTM_NEWADDR: Operation not permitted`).
            # --json emits structured event lines (thread.started, turn.started,
            # item.started/item.completed for agent_message / command_execution
            # / file_change, turn.completed) which we pretty-print below — same
            # treatment as claude's stream-json. Without --json, codex dumps
            # full unified diffs to stdout which drown the terminal.
            # stdbuf forces line buffering so events stream as produced.
            stdbuf -oL -eL codex exec --json --dangerously-bypass-approvals-and-sandbox --skip-git-repo-check "$PROMPT" > "$FIFO" 2> >(tee "$HARNESS_LOG" >&2) &
            ;;
        pi)
            # pi coding assistant — non-interactive `--print --mode json`.
            # Default text mode buffers the entire session and prints only the
            # final assistant text on exit — nothing during the run, so you'd
            # see zero progress for tens of seconds. --mode json streams a
            # JSONL event bus instead (session, agent/turn_*, message_*,
            # tool_execution_*) which the parser below renders the same way
            # the claude/codex branches do.
            # See codex notes on stdbuf and tee.
            stdbuf -oL -eL pi --print --mode json "$PROMPT" > "$FIFO" 2> >(tee "$HARNESS_LOG" >&2) &
            ;;
    esac
    CLAUDE_PID=$!

    if [ "$HARNESS" = "claude" ]; then
        while read -r line; do
            type=$(echo "$line" | jq -r '.type // empty' 2>/dev/null)
            if [ "$type" = "assistant" ]; then
                # Show text
                echo "$line" | jq -r '.message.content[]? | select(.type == "text") | .text' 2>/dev/null | while IFS= read -r text; do
                    [ -z "$text" ] && continue
                    echo -e "${BLUE}▸${NC} $text"
                done
                # Show tool calls concisely: → tool_name { inputs }
                echo "$line" | jq -c '.message.content[]? | select(.type == "tool_use")' 2>/dev/null | while read -r tool; do
                    [ -z "$tool" ] && continue
                    name=$(echo "$tool" | jq -r '.name' 2>/dev/null)
                    input=$(echo "$tool" | jq -c '.input' 2>/dev/null)
                    echo -e "${YELLOW}→${NC} ${CYAN}$name${NC} ${DIM}$input${NC}"
                done
            elif [ "$type" = "user" ]; then
                # Show tool results cleanly
                echo "$line" | jq -c '.message.content[]? | select(.type == "tool_result")' 2>/dev/null | while read -r result; do
                    [ -z "$result" ] && continue
                    is_error=$(echo "$result" | jq -r '.is_error // false' 2>/dev/null)
                    # Extract and clean content
                    content=$(echo "$result" | jq -r '
                        .content |
                        if type == "array" then
                            map(select(.type == "text") | .text) | join("\n")
                        elif type == "string" then
                            .
                        else
                            "..."
                        end
                    ' 2>/dev/null | tr -d '\r' | head -n 20)
                    # Truncate if contains base64 image data
                    if echo "$content" | grep -q '/9j/4AAQ\|data:image'; then
                        content="[image captured]"
                    fi
                    # Format line numbers: replace →  with spaces, dim the line numbers
                    formatted=$(echo "$content" | sed -E "s/^([[:space:]]*[0-9]+)→/\x1b[2m\1\x1b[0m  /")
                    if [ "$is_error" = "true" ]; then
                        echo ""
                        echo -e "${RED}✗${NC}"
                        echo -e "$formatted"
                    else
                        echo ""
                        echo -e "${DIM}○${NC}"
                        echo -e "$formatted"
                    fi
                done
            elif [ "$type" = "result" ]; then
                # Handle final result from Claude CLI
                subtype=$(echo "$line" | jq -r '.subtype // empty' 2>/dev/null)
                result_text=$(echo "$line" | jq -r '.result // empty' 2>/dev/null)
                if [ "$subtype" = "success" ] && [ -n "$result_text" ]; then
                    echo ""
                    echo -e "${GREEN}✓${NC} $result_text"
                elif [ "$subtype" = "error" ]; then
                    echo ""
                    echo -e "${RED}✗${NC} $result_text"
                else
                    echo -e "${DIM}? $line${NC}"
                fi
            elif [ "$type" != "system" ]; then
                echo -e "${DIM}? $line${NC}"
            fi
        done < "$FIFO"
    elif [ "$HARNESS" = "codex" ]; then
        # Codex --json event stream. Mirrors the claude branch above:
        # text → ▸, tool calls → →, tool results → ○ (or ✗ on failure),
        # final turn summary → ✓ tokens.
        while IFS= read -r line; do
            type=$(echo "$line" | jq -r '.type // empty' 2>/dev/null)
            case "$type" in
                item.started)
                    item_type=$(echo "$line" | jq -r '.item.type // empty' 2>/dev/null)
                    case "$item_type" in
                        command_execution)
                            cmd=$(echo "$line" | jq -r '.item.command // empty' 2>/dev/null | head -c 300)
                            echo -e "${YELLOW}→${NC} ${CYAN}bash${NC} ${DIM}$cmd${NC}"
                            ;;
                        file_change)
                            paths=$(echo "$line" | jq -r '[.item.changes[]? | "\(.kind) \(.path)"] | join(", ")' 2>/dev/null)
                            echo -e "${YELLOW}→${NC} ${CYAN}file_change${NC} ${DIM}$paths${NC}"
                            ;;
                    esac
                    ;;
                item.completed)
                    item_type=$(echo "$line" | jq -r '.item.type // empty' 2>/dev/null)
                    case "$item_type" in
                        agent_message)
                            text=$(echo "$line" | jq -r '.item.text // empty' 2>/dev/null)
                            [ -z "$text" ] && continue
                            echo -e "${BLUE}▸${NC} $text"
                            ;;
                        command_execution)
                            exit_code=$(echo "$line" | jq -r '.item.exit_code // 0' 2>/dev/null)
                            output=$(echo "$line" | jq -r '.item.aggregated_output // empty' 2>/dev/null | tr -d '\r' | head -n 20)
                            echo ""
                            if [ "$exit_code" != "0" ] && [ "$exit_code" != "null" ]; then
                                echo -e "${RED}✗${NC} exit $exit_code"
                            else
                                echo -e "${DIM}○${NC}"
                            fi
                            [ -n "$output" ] && echo -e "${DIM}$output${NC}"
                            ;;
                        file_change)
                            # Already announced on item.started; skip the duplicate.
                            ;;
                        reasoning)
                            # Internal chain-of-thought — keep quiet by default.
                            ;;
                    esac
                    ;;
                turn.completed)
                    in_tok=$(echo "$line" | jq -r '.usage.input_tokens // 0' 2>/dev/null)
                    out_tok=$(echo "$line" | jq -r '.usage.output_tokens // 0' 2>/dev/null)
                    echo ""
                    echo -e "${GREEN}✓${NC} turn complete (${in_tok} in / ${out_tok} out)"
                    ;;
                turn.failed|error)
                    msg=$(echo "$line" | jq -r '.error.message // .message // empty' 2>/dev/null)
                    echo ""
                    echo -e "${RED}✗${NC} ${msg:-codex turn failed}"
                    ;;
                thread.started|turn.started|""|null)
                    # Quiet.
                    ;;
                *)
                    echo -e "${DIM}? $line${NC}"
                    ;;
            esac
        done < "$FIFO"
    else
        # pi --mode json event stream. Mirrors claude/codex branches: assistant
        # text → ▸, tool calls → →, tool results → ○ (or ✗ on isError), turn
        # end → ✓ with token usage when available.
        while IFS= read -r line; do
            type=$(echo "$line" | jq -r '.type // empty' 2>/dev/null)
            case "$type" in
                message_end)
                    role=$(echo "$line" | jq -r '.message.role // empty' 2>/dev/null)
                    [ "$role" = "assistant" ] || continue
                    # Emit each text content block. Skip thinking and tool_use
                    # (tool_use is announced via tool_execution_start below).
                    echo "$line" | jq -r '.message.content[]? | select(.type == "text") | .text' 2>/dev/null | while IFS= read -r text; do
                        [ -z "$text" ] && continue
                        echo -e "${BLUE}▸${NC} $text"
                    done
                    ;;
                tool_execution_start)
                    name=$(echo "$line" | jq -r '.toolName // empty' 2>/dev/null)
                    args=$(echo "$line" | jq -c '.args // {}' 2>/dev/null | head -c 300)
                    echo -e "${YELLOW}→${NC} ${CYAN}$name${NC} ${DIM}$args${NC}"
                    ;;
                tool_execution_end)
                    is_error=$(echo "$line" | jq -r '.isError // false' 2>/dev/null)
                    # pi tool results commonly come back as
                    #   {content: [{type:"text", text:"..."}], details: {...}}
                    # so unwrap .content[].text first; fall back to other
                    # common shapes.
                    result=$(echo "$line" | jq -r '
                        .result |
                        if type == "array" then
                            map(select(.type == "text") | .text) | join("\n")
                        elif type == "string" then
                            .
                        elif type == "object" then
                            if (.content | type) == "array" then
                                [.content[] | select(.type == "text") | .text] | join("\n")
                            else
                                (.text // .output // .stdout // .message // (. | tostring))
                            end
                        else
                            (. | tostring)
                        end
                    ' 2>/dev/null | tr -d '\r' | head -n 20)
                    echo ""
                    if [ "$is_error" = "true" ]; then
                        echo -e "${RED}✗${NC}"
                    else
                        echo -e "${DIM}○${NC}"
                    fi
                    [ -n "$result" ] && echo -e "${DIM}$result${NC}"
                    ;;
                turn_end|agent_end)
                    # pi attaches usage on message_end; turn_end is just a marker.
                    if [ "$type" = "agent_end" ]; then
                        echo ""
                        echo -e "${GREEN}✓${NC} pi finished"
                    fi
                    ;;
                session|session_start|agent_start|turn_start|message_start|message_update|tool_execution_update|""|null)
                    # Quiet — message_update is mostly thinking/text deltas; we
                    # let message_end render the final blocks instead.
                    ;;
                error)
                    msg=$(echo "$line" | jq -r '.message // .error // empty' 2>/dev/null)
                    echo ""
                    echo -e "${RED}✗${NC} ${msg:-pi error}"
                    ;;
                *)
                    echo -e "${DIM}? $line${NC}"
                    ;;
            esac
        done < "$FIFO"
    fi

    rm -f "$FIFO"
    wait "$CLAUDE_PID" 2>/dev/null
    HARNESS_EXIT=$?
    CLAUDE_PID=""

    if [ "$HARNESS_EXIT" -ne 0 ] && [ -s "$HARNESS_LOG" ]; then
        echo ""
        echo -e "${RED}✗${NC} $HARNESS exited with status $HARNESS_EXIT. stderr:"
        sed 's/^/   /' "$HARNESS_LOG" | head -n 20
    fi
    rm -f "$HARNESS_LOG"

    echo ""
    echo -e "${GREEN}✓${NC} Iteration $ITERATION complete"
    echo ""
    sleep 2
done

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}■${NC} Ralph loop finished"
echo "   Total iterations: $ITERATION"
echo "   Ended: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
case "$MODE" in
    files)
        echo -e "${BLUE}▸${NC} Final pending tickets:"
        list_pending
        ;;
    beads)
        echo -e "${BLUE}▸${NC} Final beads status:"
        bd ready 2>/dev/null || echo "   No beads ready"
        ;;
esac
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
