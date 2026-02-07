#!/bin/bash
# CodeSensei — Track Code Change Hook (PostToolUse: Write|Edit|MultiEdit)
# Records what files Claude creates or modifies for contextual teaching
# This data is used by /explain and /recap to know what happened

PROFILE_DIR="$HOME/.code-sensei"
PROFILE_FILE="$PROFILE_DIR/profile.json"
CHANGES_LOG="$PROFILE_DIR/session-changes.jsonl"

# Read hook input from stdin
INPUT=$(cat)

if [ ! -d "$PROFILE_DIR" ]; then
  mkdir -p "$PROFILE_DIR"
fi

if command -v jq &> /dev/null; then
  # Extract file path and tool info from hook input
  TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // "unknown"')
  TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Detect file type/technology for concept mapping
  EXTENSION="${FILE_PATH##*.}"
  TECH=""
  case "$EXTENSION" in
    html|htm) TECH="html" ;;
    css|scss|sass|less) TECH="css" ;;
    js|mjs) TECH="javascript" ;;
    jsx) TECH="react" ;;
    ts|tsx) TECH="typescript" ;;
    py) TECH="python" ;;
    sql) TECH="sql" ;;
    json) TECH="json" ;;
    md|mdx) TECH="markdown" ;;
    sh|bash) TECH="shell" ;;
    yaml|yml) TECH="yaml" ;;
    toml) TECH="toml" ;;
    env) TECH="environment-variables" ;;
    dockerfile|Dockerfile) TECH="docker" ;;
    *) TECH="other" ;;
  esac

  # Log the change
  echo "{\"timestamp\":\"$TIMESTAMP\",\"tool\":\"$TOOL_NAME\",\"file\":\"$FILE_PATH\",\"extension\":\"$EXTENSION\",\"tech\":\"$TECH\"}" >> "$CHANGES_LOG"

  # Track technology in session concepts if it's new
  if [ -f "$PROFILE_FILE" ] && [ "$TECH" != "other" ]; then
    ALREADY_SEEN=$(jq --arg tech "$TECH" '.session_concepts | index($tech)' "$PROFILE_FILE")
    if [ "$ALREADY_SEEN" = "null" ]; then
      UPDATED=$(jq --arg tech "$TECH" '.session_concepts += [$tech]' "$PROFILE_FILE")
      echo "$UPDATED" > "$PROFILE_FILE"
    fi

    # Also add to lifetime concepts_seen if new
    LIFETIME_SEEN=$(jq --arg tech "$TECH" '.concepts_seen | index($tech)' "$PROFILE_FILE")
    if [ "$LIFETIME_SEEN" = "null" ]; then
      UPDATED=$(jq --arg tech "$TECH" '.concepts_seen += [$tech]' "$PROFILE_FILE")
      echo "$UPDATED" > "$PROFILE_FILE"
    fi
  fi
fi

exit 0
