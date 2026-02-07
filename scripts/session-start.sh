#!/bin/bash
# CodeSensei — Session Start Hook
# Loads user profile and updates streak on each Claude Code session start

PROFILE_DIR="$HOME/.code-sensei"
PROFILE_FILE="$PROFILE_DIR/profile.json"
SESSION_LOG="$PROFILE_DIR/sessions.log"
TODAY=$(date -u +%Y-%m-%d)

# Create profile directory if it doesn't exist
mkdir -p "$PROFILE_DIR"

# Create default profile if none exists
if [ ! -f "$PROFILE_FILE" ]; then
  cat > "$PROFILE_FILE" << PROFILE
{
  "version": "1.0.0",
  "plugin": "code-sensei",
  "brand": "Dojo Coding",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "belt": "white",
  "xp": 0,
  "streak": {
    "current": 1,
    "longest": 1,
    "last_session_date": "$TODAY"
  },
  "quizzes": {
    "total": 0,
    "correct": 0,
    "current_streak": 0,
    "longest_streak": 0
  },
  "concepts_seen": [],
  "concepts_mastered": [],
  "skills_progress": {},
  "quiz_history": [],
  "sessions": {
    "total": 1,
    "first_session": "$TODAY",
    "last_session": "$TODAY"
  },
  "achievements": [
    {
      "id": "first-session",
      "name": "First Steps",
      "description": "Started your first CodeSensei session",
      "earned_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    }
  ],
  "preferences": {
    "difficulty": "auto",
    "analogy_domain": null,
    "show_hints": true
  },
  "session_concepts": []
}
PROFILE
  echo "🥋 Welcome to CodeSensei by Dojo Coding! Use /code-sensei:progress to get started."
  exit 0
fi

# Profile exists — update streak and session count
if command -v jq &> /dev/null; then
  LAST_SESSION=$(jq -r '.streak.last_session_date // ""' "$PROFILE_FILE")
  CURRENT_STREAK=$(jq -r '.streak.current // 0' "$PROFILE_FILE")
  LONGEST_STREAK=$(jq -r '.streak.longest // 0' "$PROFILE_FILE")
  TOTAL_SESSIONS=$(jq -r '.sessions.total // 0' "$PROFILE_FILE")

  # Calculate streak
  if [ "$LAST_SESSION" = "$TODAY" ]; then
    # Already logged today, no streak change
    NEW_STREAK=$CURRENT_STREAK
  elif [ -n "$LAST_SESSION" ]; then
    # Check if last session was yesterday
    YESTERDAY=$(date -u -d "yesterday" +%Y-%m-%d 2>/dev/null || date -u -v-1d +%Y-%m-%d 2>/dev/null)
    if [ "$LAST_SESSION" = "$YESTERDAY" ]; then
      NEW_STREAK=$((CURRENT_STREAK + 1))
    else
      NEW_STREAK=1
    fi
  else
    NEW_STREAK=1
  fi

  # Update longest streak
  if [ "$NEW_STREAK" -gt "$LONGEST_STREAK" ]; then
    NEW_LONGEST=$NEW_STREAK
  else
    NEW_LONGEST=$LONGEST_STREAK
  fi

  # Update profile
  UPDATED=$(jq \
    --arg today "$TODAY" \
    --argjson streak "$NEW_STREAK" \
    --argjson longest "$NEW_LONGEST" \
    --argjson sessions "$((TOTAL_SESSIONS + 1))" \
    '.streak.current = $streak |
     .streak.longest = $longest |
     .streak.last_session_date = $today |
     .sessions.total = $sessions |
     .sessions.last_session = $today |
     .session_concepts = []' \
    "$PROFILE_FILE")

  echo "$UPDATED" > "$PROFILE_FILE"

  # Log session
  echo "$TODAY $(date -u +%H:%M:%S) session_start" >> "$SESSION_LOG"

  # Show streak info if notable
  BELT=$(jq -r '.belt // "white"' "$PROFILE_FILE")
  XP=$(jq -r '.xp // 0' "$PROFILE_FILE")

  if [ "$NEW_STREAK" -ge 7 ] && [ "$NEW_STREAK" != "$CURRENT_STREAK" ]; then
    echo "🔥 $NEW_STREAK-day streak! Consistency is the Dojo Way."
  fi
fi

exit 0
