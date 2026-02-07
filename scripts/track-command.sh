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
    fi
  fi
fi

exit 0
