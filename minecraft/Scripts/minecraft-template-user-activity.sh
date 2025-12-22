#!/usr/bin/env bash
set -euo pipefail

# Injected by Nix 
RSYNC_BIN="@RSYNC_BIN@"
DATA_DIR="@DATA_DIR@"
MCSTATUS_BIN="@MCSTATUS_BIN@"
MCRCON_BIN="@MCRCON_BIN@"
AWK_BIN="@AWK_BIN@"
QUERY_PORT="@QUERY_PORT@"
RCON_PORT="@RCON_PORT@"
RCON_PASSWORD="@RCON_PASSWORD@"
SERVER_NAME="@SERVER_NAME@"
TAR_BIN="@TAR_BIN@"
ZIP_BIN="@ZIP_BIN@"
UNZIP_BIN="@UNZIP_BIN@"
GZIP_BIN="@GZIP_BIN@"
ZSTD_BIN="@ZSTD_BIN@"
PV_BIN="@PV_BIN@"
DU_BIN="@DU_BIN@"
BZIP2_BIN="@BZIP2_BIN@"
XZ_BIN="@XZ_BIN@"

# Convenience wrappers 
rsync_cmd="$RSYNC_BIN"
awk_cmd="$AWK_BIN"
mcstatus_cmd="$MCSTATUS_BIN 127.0.0.1:${QUERY_PORT}"
mcrcon_cmd="$MCRCON_BIN -H 127.0.0.1 -P ${RCON_PORT} -p ${RCON_PASSWORD}"
tar_cmd="$TAR_BIN"
zip_cmd="$ZIP_BIN"
unzip_cmd="$UNZIP_BIN"
gzip_cmd="$GZIP_BIN"
zstd_cmd="$ZSTD_BIN"
pv_cmd="$PV_BIN"
du_cmd="$DU_BIN"
bzip2_cmd="$BZIP2_BIN"
xz_cmd="$XZ_BIN"


# Provided by systemd Environment
QUERY_BIN="${QUERY_BIN:-minecraft-${SERVER_NAME}-query}"

ACTIVITY_FILE="$DATA_DIR/$SERVER_NAME/UserActivity"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

mkdir -p "$(dirname "$ACTIVITY_FILE")"
touch "$ACTIVITY_FILE"

OUTPUT="$($QUERY_BIN || true)"

PLAYER_LINE="$(echo "$OUTPUT" | grep '^players:' || true)"

ONLINE="$(echo "$PLAYER_LINE" | awk_cmd '{print $2}' | cut -d/ -f1)"

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
