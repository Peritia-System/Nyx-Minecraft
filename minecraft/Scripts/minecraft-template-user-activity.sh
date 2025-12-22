#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="@DATA_DIR@"
SERVER_NAME="@SERVER_NAME@"

# Provided by systemd Environment
QUERY_BIN="${QUERY_BIN:-minecraft-${SERVER_NAME}-query}"

ACTIVITY_FILE="$DATA_DIR/$SERVER_NAME/UserActivity"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

mkdir -p "$(dirname "$ACTIVITY_FILE")"
touch "$ACTIVITY_FILE"

OUTPUT="$($QUERY_BIN || true)"

PLAYER_LINE="$(echo "$OUTPUT" | grep '^players:' || true)"

ONLINE="$(echo "$PLAYER_LINE" | awk '{print $2}' | cut -d/ -f1)"

if [[ -z "$ONLINE" || "$ONLINE" == "0" ]]; then
  echo "[$TIMESTAMP] No user detected" >> "$ACTIVITY_FILE"
  exit 0
fi

PLAYERS="$(echo "$PLAYER_LINE" | sed -n 's/.*\[\(.*\)\]/\1/p')"

IFS=',' read -ra PLAYER_ARRAY <<< "$PLAYERS"

for player in "${PLAYER_ARRAY[@]}"; do
  player="$(echo "$player" | xargs)"
  [[ -n "$player" ]] && echo "[$TIMESTAMP] $player was logged in" >> "$ACTIVITY_FILE"
done
