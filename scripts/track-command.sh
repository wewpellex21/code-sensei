#!/bin/bash
# CodeSensei — Track Command Hook (PostToolUse: Bash)
# Records what shell commands Claude runs for contextual teaching
# Helps /explain and /recap know what tools/packages were used

PROFILE_DIR="$HOME/.code-sensei"
PROFILE_FILE="$PROFILE_DIR/profile.json"
COMMANDS_LOG="$PROFILE_DIR/session-commands.jsonl"

# Read hook input from stdin
INPUT=$(cat)

if [ ! -d "$PROFILE_DIR" ]; then
  mkdir -p "$PROFILE_DIR"
fi

if command -v jq &> /dev/null; then
  COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // "unknown"')
  TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Detect what kind of command this is for concept tracking
  CONCEPT=""
  case "$COMMAND" in
    *"npm install"*|*"npm i "*|*"yarn add"*|*"pnpm add"*)
      CONCEPT="package-management"
      # Extract package name for tracking
      PACKAGE=$(echo "$COMMAND" | sed -E 's/.*(npm install|npm i|yarn add|pnpm add)[[:space:]]+([^[:space:]]+).*/\2/' | head -1)
      ;;
    *"pip install"*|*"pip3 install"*)
      CONCEPT="package-management"
      ;;
    *"git "*) CONCEPT="git" ;;
    *"docker "*) CONCEPT="docker" ;;
    *"curl "*|*"wget "*) CONCEPT="http-requests" ;;
    *"mkdir "*|*"touch "*|*"cp "*|*"mv "*|*"rm "*) CONCEPT="file-system" ;;
    *"node "*|*"npx "*) CONCEPT="nodejs-runtime" ;;
    *"python "*|*"python3 "*) CONCEPT="python-runtime" ;;
    *"psql "*|*"mysql "*|*"sqlite3 "*) CONCEPT="database-cli" ;;
    *"cd "*|*"ls "*|*"pwd"*) CONCEPT="terminal-navigation" ;;
    *"chmod "*|*"chown "*) CONCEPT="permissions" ;;
    *"ssh "*|*"scp "*) CONCEPT="remote-access" ;;
    *"env "*|*"export "*) CONCEPT="environment-variables" ;;
    *"test "*|*"jest "*|*"vitest "*|*"pytest "*) CONCEPT="testing" ;;
    *) CONCEPT="" ;;
  esac

  # Log the command
  echo "{\"timestamp\":\"$TIMESTAMP\",\"command\":\"$(echo "$COMMAND" | head -c 200)\",\"concept\":\"$CONCEPT\"}" >> "$COMMANDS_LOG"

  # Track concept in session and lifetime if new and meaningful
  IS_FIRST_EVER="false"
  if [ -n "$CONCEPT" ] && [ -f "$PROFILE_FILE" ]; then
    ALREADY_SEEN=$(jq --arg c "$CONCEPT" '.session_concepts | index($c)' "$PROFILE_FILE")
    if [ "$ALREADY_SEEN" = "null" ]; then
      UPDATED=$(jq --arg c "$CONCEPT" '.session_concepts += [$c]' "$PROFILE_FILE")
      echo "$UPDATED" > "$PROFILE_FILE"
    fi

    LIFETIME_SEEN=$(jq --arg c "$CONCEPT" '.concepts_seen | index($c)' "$PROFILE_FILE")
    if [ "$LIFETIME_SEEN" = "null" ]; then
      UPDATED=$(jq --arg c "$CONCEPT" '.concepts_seen += [$c]' "$PROFILE_FILE")
      echo "$UPDATED" > "$PROFILE_FILE"
      IS_FIRST_EVER="true"
    fi
  fi

  # Always inject teaching context after commands
  BELT=$(jq -r '.belt // "white"' "$PROFILE_FILE" 2>/dev/null || echo "white")
  # Sanitize command for JSON (remove quotes and special chars)
  SAFE_CMD=$(echo "$COMMAND" | head -c 80 | tr '"' "'" | tr '\\' '/')

  if [ "$IS_FIRST_EVER" = "true" ] && [ -n "$CONCEPT" ]; then
    # First-time encounter: micro-lesson about the concept
    CONTEXT="🥋 CodeSensei micro-lesson trigger: The user just encountered '$CONCEPT' for the FIRST TIME (command: $SAFE_CMD). Their belt level is '$BELT'. Provide a brief 2-sentence explanation of what $CONCEPT means and why it matters. Adapt language to their belt level. Keep it concise and non-intrusive."
  elif [ -n "$CONCEPT" ]; then
    # Already-seen concept: brief inline insight about this specific command
    CONTEXT="🥋 CodeSensei inline insight: Claude just ran a '$CONCEPT' command ($SAFE_CMD). The user's belt level is '$BELT'. Provide a brief 1-sentence explanation of what this command does, adapted to their belt level. Keep it natural and non-intrusive."
  else
    # Unknown command type: still provide a brief hint
    CONTEXT="🥋 CodeSensei inline insight: Claude just ran a shell command ($SAFE_CMD). The user's belt level is '$BELT'. If this command is educational, briefly explain what it does in 1 sentence. If trivial, skip the explanation."
  fi

  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"$CONTEXT\"}}"
fi

exit 0
