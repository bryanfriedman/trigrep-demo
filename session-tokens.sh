#!/usr/bin/env bash
#
# Reports token usage for a coding agent session.
#
# Usage: ./session-tokens.sh <session-id> [claude|copilot]
#   session-id  The session ID to look up
#   agent       Which agent's logs to parse (default: claude)

set -euo pipefail

SESSION_ID="${1:-}"
AGENT="${2:-claude}"

if [ -z "$SESSION_ID" ]; then
  echo "Usage: $0 <session-id> [claude|copilot]"
  exit 1
fi

# ─── Claude ───────────────────────────────────────────────────────────────────

report_claude() {
  local MAIN_LOG
  MAIN_LOG=$(find ~/.claude/projects -maxdepth 2 -name "$SESSION_ID.jsonl" 2>/dev/null | head -1)

  if [ -z "$MAIN_LOG" ]; then
    echo "Session not found: $SESSION_ID"
    exit 1
  fi

  local PROJECT_DIR
  PROJECT_DIR=$(dirname "$MAIN_LOG")
  local SUBAGENT_DIR="$PROJECT_DIR/$SESSION_ID/subagents"

  sum_tokens() {
    python3 -c "
import json, sys

totals = {'input': 0, 'output': 0, 'cache_create': 0, 'cache_read': 0}
entries = 0

for filepath in sys.argv[1:]:
    with open(filepath) as f:
        for line in f:
            try:
                obj = json.loads(line)
                usage = obj.get('usage') or obj.get('message', {}).get('usage')
                if usage:
                    totals['input'] += usage.get('input_tokens', 0)
                    totals['output'] += usage.get('output_tokens', 0)
                    totals['cache_create'] += usage.get('cache_creation_input_tokens', 0)
                    totals['cache_read'] += usage.get('cache_read_input_tokens', 0)
                    entries += 1
            except json.JSONDecodeError:
                pass

total = totals['input'] + totals['output'] + totals['cache_create'] + totals['cache_read']
print(f\"  Uses:          {entries}\")
print(f\"  Input:         {totals['input']:,}\")
print(f\"  Output:        {totals['output']:,}\")
print(f\"  Cache create:  {totals['cache_create']:,}\")
print(f\"  Cache read:    {totals['cache_read']:,}\")
print(f\"  Total tokens:  {total:,}\")
" "$@"
  }

  echo "=== Main session ==="
  if [ -f "$MAIN_LOG" ]; then
    sum_tokens "$MAIN_LOG"
  else
    echo "  Not found: $MAIN_LOG"
  fi

  echo ""
  echo "=== Subagents ==="
  if [ -d "$SUBAGENT_DIR" ]; then
    for f in "$SUBAGENT_DIR"/*.jsonl; do
      echo "  --- $(basename "$f") ---"
      sum_tokens "$f"
      echo ""
    done
  else
    echo "  No subagents found"
  fi

  echo ""
  echo "=== Combined total ==="
  local ALL_FILES="$MAIN_LOG"
  if [ -d "$SUBAGENT_DIR" ]; then
    ALL_FILES="$ALL_FILES $SUBAGENT_DIR/*.jsonl"
  fi
  sum_tokens $ALL_FILES
}

# ─── Copilot ──────────────────────────────────────────────────────────────────

report_copilot() {
  local BASE_DIR="$HOME/.copilot/session-state"
  local EVENTS="$BASE_DIR/$SESSION_ID/events.jsonl"

  if [ ! -f "$EVENTS" ]; then
    echo "Error: $EVENTS not found"
    exit 1
  fi

  local selected_model
  selected_model=$(grep '"session.start"' "$EVENTS" | head -1 | sed -n 's/.*"selectedModel":"\([^"]*\)".*/\1/p')
  echo "Session:  $SESSION_ID"

  grep '"session.shutdown"' "$EVENTS" | \
    sed 's/.*"modelMetrics":{//' | \
    grep -o '"[^"]*":{"requests":{"count":[0-9]*,"cost":[0-9]*},"usage":{"inputTokens":[0-9]*,"outputTokens":[0-9]*,"cacheReadTokens":[0-9]*,"cacheWriteTokens":[0-9]*}}' | \
    awk -v primary_model="$selected_model" -F'[":,{}]+' '{
      model=""; reqs=0; input=0; output=0; cread=0; cwrite=0
      for (i=1; i<=NF; i++) {
        if ($i == "requests") { for (j=i+1; j<=NF; j++) { if ($j == "count") { reqs=$(j+1); break } } }
        if ($i == "inputTokens") { input=$(i+1) }
        if ($i == "outputTokens") { output=$(i+1) }
        if ($i == "cacheReadTokens") { cread=$(i+1) }
        if ($i == "cacheWriteTokens") { cwrite=$(i+1) }
      }
      for (i=1; i<=NF; i++) { if ($i != "" && $i !~ /^(requests|count|cost|usage|inputTokens|outputTokens|cacheReadTokens|cacheWriteTokens|[0-9]+)$/) { model=$i; break } }
      if (agent_model == "") {
        agent_model = primary_model
        if (agent_model == "" || agent_model == "unknown") {
          agent_model = model
        }
      }
      bucket = (model == agent_model) ? "Agent" : "Subagents"
      groups[bucket] = 1
      req_count[bucket] += reqs
      input_tok[bucket] += input
      output_tok[bucket] += output
      cache_read[bucket] += cread
      cache_write[bucket] += cwrite
      total_reqs += reqs
      total_input += input
      total_output += output
      total_cread += cread
      total_cwrite += cwrite
      n_groups = length(groups)
    }
    END {
      split("Agent Subagents", order, " ")
      for (k=1; k<=2; k++) {
        g = order[k]
        if (!(g in groups)) continue
        group_total = input_tok[g] + output_tok[g] + cache_read[g] + cache_write[g]
        printf "  %s\n", g
        printf "    Requests:           %\047d\n", req_count[g]
        printf "    Input tokens:       %\047d\n", input_tok[g]
        printf "    Output tokens:      %\047d\n", output_tok[g]
        printf "    Cache read tokens:  %\047d\n", cache_read[g]
        printf "    Cache write tokens: %\047d\n", cache_write[g]
        printf "    TOTAL tokens:       %\047d\n", group_total
        printf "\n"
      }
      if (n_groups > 1) {
        grand_total = total_input + total_output + total_cread + total_cwrite
        printf "  Total (agent + subagent)\n"
        printf "    Requests:           %\047d\n", total_reqs
        printf "    Input tokens:       %\047d\n", total_input
        printf "    Output tokens:      %\047d\n", total_output
        printf "    Cache read tokens:  %\047d\n", total_cread
        printf "    Cache write tokens: %\047d\n", total_cwrite
        printf "    TOTAL tokens:       %\047d\n", grand_total
      }
    }'
}

# ─── Dispatch ─────────────────────────────────────────────────────────────────

case "$AGENT" in
  claude)
    report_claude
    ;;
  copilot)
    report_copilot
    ;;
  *)
    echo "Unknown agent: $AGENT (expected 'claude' or 'copilot')"
    exit 1
    ;;
esac
