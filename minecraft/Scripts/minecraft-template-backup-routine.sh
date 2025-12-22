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
WC_BIN="@WC_BIN@"
FIND_BIN="@FIND_BIN@"


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
wc_cmd="$WC_BIN"
find_cmd="$FIND_BIN"



# PATH extension 
# (only figured that out later if you add it here it can actually just use the bin)
# So you can easily just switch out the "*_cmd" with the "normal" name 
# Extend PATH with all injected binaries so we can call them directly
for bin in \
  "$GZIP_BIN" \
  "$ZSTD_BIN" \
  "$PV_BIN" \
  "$DU_BIN" \
  "$BZIP2_BIN" \
  "$XZ_BIN" \
  "$WC_BIN" \
  "$FIND_BIN"
do
  export PATH="$(dirname "$bin"):$PATH"
done



# Defaults 
REBOOT=false
SLEEP_TIME=0
FULL=false
DESTINATION="/srv/minecraft/backups/unknown"
PURE=false
FORMAT="tar"
COMPRESSION="gzip"
PROGRESS_INTERVAL=5   # default to 5 seconds

CHECK_USER=false
USER_ACTIVITY_FILE="UserActivity"


# Usage 
usage() {
  cat <<EOF
Usage: $0 [--reboot] [--sleep <seconds>] [--full] [--destination <path>] [--pure]
          [--format <tar|zip>] [--compression <gzip|bzip2|xz|zstd>] [--progressInterval <seconds>]

  --reboot        Stop server before backup and start afterwards [DOES NOT WORK]
  --sleep N       Wait N seconds with countdown announcements
  --progressInterval N    Wait N seconds with interval announcements (default: 5)
  --full          Backup entire server directory (default: world only)
  --destination X Backup target directory (default: /srv/minecraft/backups/unknown)
  --pure          Use rsync to copy files (no compression, symlinks resolved)
  --format X      Archive format: tar or zip (ignored if --pure)
  --compression X Compression for tar (default: gzip)
  --check-user   Only run backup if unbackuped user activity exists

EOF
  exit 1
}

# Argument parsing 
echo "[DEBUG] Parsing command-line arguments..."
while [[ $# -gt 0 ]]; do
  case "$1" in
    --reboot) echo "[DEBUG] Flag: --reboot"; REBOOT=true; shift ;;
    --sleep) echo "[DEBUG] Flag: --sleep $2"; SLEEP_TIME="$2"; shift 2 ;;
    --full) echo "[DEBUG] Flag: --full"; FULL=true; shift ;;
    --destination) echo "[DEBUG] Flag: --destination $2"; DESTINATION="$2"; shift 2 ;;
    --pure) echo "[DEBUG] Flag: --pure"; PURE=true; shift ;;
    --format) echo "[DEBUG] Flag: --format $2"; FORMAT="$2"; shift 2 ;;
    --compression) echo "[DEBUG] Flag: --compression $2"; COMPRESSION="$2"; shift 2 ;;
    --progressInterval) echo "[DEBUG] Flag: --progressInterval $2"; PROGRESS_INTERVAL="$2"; shift 2 ;;
    --check-user) echo "[DEBUG] Flag: --check-user"; CHECK_USER=true; shift ;;

    --help) usage ;;
    *) echo "[ERROR] Unknown option: $1"; usage ;;
  esac
done

# Restart if rebooting 
if [[ "$REBOOT" == true ]]; then
  echo "[DEBUG] Restarting server does not work"
  echo "[DEBUG] The sudo can't be enabled due to it not being used by the same path as for the systemd"
  echo "[DEBUG] and just using systemctl won't work either due to it not having the rights to stop it"
  echo "[DEBUG] if you fix this pls make a PR"

fi



# Helpers 

say_with_color() {
  local color="$1"
  shift
  local message="$*"
  local code

  case "$color" in
    black) code="§0" ;;
    dark_blue) code="§1" ;;
    dark_green) code="§2" ;;
    dark_aqua) code="§3" ;;
    dark_red) code="§4" ;;
    dark_purple) code="§5" ;;
    gold) code="§6" ;;
    gray) code="§7" ;;
    dark_gray) code="§8" ;;
    blue) code="§9" ;;
    green) code="§a" ;;
    aqua) code="§b" ;;
    red) code="§c" ;;
    light_purple|pink) code="§d" ;;
    yellow) code="§e" ;;
    white) code="§f" ;;
    obfuscated) code="§k" ;;
    bold) code="§l" ;;
    strikethrough) code="§m" ;;
    underline) code="§n" ;;
    italic) code="§o" ;;
    reset) code="§r" ;;
    *) code="" ;;
  esac

  local full_message="${code}${message}§r"
# echo "[DEBUG] Sending RCON say: $full_message"
  $mcrcon_cmd "say $full_message"
}

say() {
  echo "[INFO] $1"
  say_with_color yellow "$1"
}



countdown() {
  local seconds="$1"

  #echo "[DEBUG] Starting countdown of $seconds seconds..."
  say "Backup will start in $seconds seconds"
 
  while [ "$seconds" -gt 0 ]; do
    #echo "  $seconds"

    # Logic for when to speak updates
    if   [ "$seconds" -le 15 ]; then
      say "$seconds"
    elif [ "$seconds" -le 60 ] && (( seconds % 10 == 0 )); then
      say "$seconds seconds remaining"
    elif [ "$seconds" -le 120 ] && (( seconds % 30 == 0 )); then
      say "$seconds seconds remaining"
    elif [ "$seconds" -le 300 ] && (( seconds % 60 == 0 )); then
      say "$seconds seconds remaining"
    fi

    sleep 1
    ((seconds--))
  done

  echo
  say "Countdown finished. Starting backup now."
}



check_user_activity() {
  local activity_file="$DATA_DIR/$SERVER_NAME/$USER_ACTIVITY_FILE"

  if [[ ! -f "$activity_file" ]]; then
    echo "[WARN] User activity file not found: $activity_file"
    return 1
  fi

  # Find unbackuped login lines
  if ! grep -E 'was logged in' "$activity_file" | grep -vq '\[backuped\]'; then
    echo "[INFO] No unbackuped user activity detected."
    return 1
  fi

  echo "[INFO] Unbackuped user activity detected."
  return 0
}

mark_user_activity_backuped() {
  local activity_file="$DATA_DIR/$SERVER_NAME/$USER_ACTIVITY_FILE"

  # Append [backuped] to all unbackuped login lines
  sed -i \
    -e '/was logged in/{
          /\[backuped\]/! s/$/ [backuped]/
        }' \
    "$activity_file"
}


do_backup() {
  local backup_source=""
  local backup_destination=""
  local backup_compression="gzip"
  local backup_format="tar"
  local backup_pure=false
  local progress_interval=$PROGRESS_INTERVAL

  # Parse args
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --source)      backup_source="$2"; shift 2 ;;
      --destination) backup_destination="$2"; shift 2 ;;
      --compression) backup_compression="$2"; shift 2 ;;
      --format)      backup_format="$2"; shift 2 ;;
      --pure)        backup_pure=true; shift ;;
      *) echo "[ERROR] Unknown option to do_backup: $1"; return 1 ;;
    esac
  done

  if [[ -z "$backup_source" || -z "$backup_destination" ]]; then
    echo "[ERROR] Missing --source or --destination"
    return 1
  fi

  local timestamp="$(date +%Y%m%d-%H%M%S)"
  local full_source_path="$DATA_DIR/$backup_source"
  local source_basename="$(basename "$backup_source")"
  local archive_path=""
  local archive_ext=""

  if [[ ! -d "$full_source_path" ]]; then
    echo "[ERROR] Source directory not found: $full_source_path"
    return 1
  fi

  mkdir -p "$backup_destination"

  # PURE (rsync) backup
  if [[ "$backup_pure" == true ]]; then
    local target_path="$backup_destination/${source_basename}-${timestamp}"
    echo "[INFO] Performing pure rsync backup to $target_path"

    local progress_last_percent=-1
    local progress_last_time=$(date +%s)

    "$rsync_cmd" -rptgoDL --delete --info=progress2 --stats \
        "$full_source_path/" "$target_path/" 2>&1 | \
        while IFS= read -r -d $'\r' chunk; do
          if [[ $chunk =~ ([0-9]{1,3})% ]]; then
            local progress_percent=${BASH_REMATCH[1]}
            local now=$(date +%s)
            if [[ $progress_percent -ne $progress_last_percent ]] && \
               (( now - progress_last_time >= progress_interval )); then
              say "Progress: ${progress_percent}%"
              progress_last_percent=$progress_percent
              progress_last_time=$now
            fi
          fi
        done
    return 0
  fi

  # ARCHIVE backup
  case "$backup_format" in
    tar)
      case "$backup_compression" in
        none)  archive_ext="tar";    tar_create=( "$tar_cmd" -cvf ) ;;
        gzip)  archive_ext="tar.gz"; tar_create=( "$tar_cmd" --use-compress-program="$gzip_cmd" -cvf ) ;;
        bzip2) archive_ext="tar.bz2";tar_create=( "$tar_cmd" --use-compress-program="$bzip2_cmd" -cvf ) ;;
        xz)    archive_ext="tar.xz"; tar_create=( "$tar_cmd" --use-compress-program="$xz_cmd" -cvf ) ;;
        zstd)  archive_ext="tar.zst";tar_create=( "$tar_cmd" --use-compress-program="$zstd_cmd" -cvf ) ;;
        *) echo "[ERROR] Unsupported tar compression: $backup_compression" >&2; return 1 ;;
      esac

      archive_path="$backup_destination/${source_basename}-${timestamp}.${archive_ext}"
      echo "[INFO] Creating tar archive $archive_path"

      local progress_total=$(find "$full_source_path" | wc -l)
      local progress_done=0
      local progress_last_percent=-1
      local progress_last_time=$(date +%s)

      (
        "${tar_create[@]}" "$archive_path" -C "$DATA_DIR" "$backup_source"
      ) 2>&1 | while read -r line; do
        if [[ -n "$line" ]]; then
          progress_done=$(( progress_done + 1 ))
          if (( progress_total > 0 )); then
            local progress_percent=$(( progress_done * 100 / progress_total ))
            local now=$(date +%s)
            if (( progress_percent != progress_last_percent )) && \
               (( now - progress_last_time >= progress_interval )); then
              say "Progress: ${progress_percent}%"
              progress_last_percent=$progress_percent
              progress_last_time=$now
            fi
          fi
        fi
      done

      [[ $progress_last_percent -lt 100 ]] && say "Progress: 100%"
      echo "[INFO] Tar archive created: $archive_path"
      ;;

    zip)
      archive_path="$backup_destination/${source_basename}-${timestamp}.zip"
      echo "[INFO] Creating zip archive $archive_path"

      local progress_total=$(find "$full_source_path" | wc -l)
      local progress_done=0
      local progress_last_percent=-1
      local progress_last_time=$(date +%s)

      (
        cd "$DATA_DIR"
        "$zip_cmd" -r "$archive_path" "$backup_source"
      ) 2>&1 | while read -r line; do
        if [[ $line =~ adding: ]]; then
          progress_done=$(( progress_done + 1 ))
          if (( progress_total > 0 )); then
            local progress_percent=$(( progress_done * 100 / progress_total ))
            local now=$(date +%s)
            if (( progress_percent != progress_last_percent )) && \
               (( now - progress_last_time >= progress_interval )); then
              say "Progress: ${progress_percent}%"
              progress_last_percent=$progress_percent
              progress_last_time=$now
            fi
          fi
        fi
      done

      [[ $progress_last_percent -lt 100 ]] && say "Progress: 100%"
      echo "[INFO] Zip archive created: $archive_path"
      ;;

    *)
      echo "[ERROR] Unsupported format: $backup_format"
      return 1
      ;;
  esac

  echo "[INFO] Backup completed: $archive_path"
  return 0
}




# MAIN

#echo "[DEBUG] FULL=$FULL"

if [[ "$CHECK_USER" == true ]]; then
  echo "[INFO] Running in --check-user mode"
  if ! check_user_activity; then
    echo "[INFO] Skipping backup due to no user activity."
    exit 0
  fi
fi


if [[ "$FULL" == true ]]; then
  BACKUP_SOURCE="${SERVER_NAME}"
  BACKUP_MODE="full server directory"
  DESTINATION="${DESTINATION}/Full"
else
  BACKUP_SOURCE="${SERVER_NAME}/world"
  BACKUP_MODE="world folder only"
  DESTINATION="${DESTINATION}/World"
fi

say "Backup for ($BACKUP_MODE) initiated"

# Pre-backup wait 
if (( SLEEP_TIME > 0 )); then
  countdown "$SLEEP_TIME"
fi

mkdir -p "$DESTINATION"

echo "[INFO] Running backup of $BACKUP_MODE to $DESTINATION..."
if do_backup \
      --source "$BACKUP_SOURCE" \
      --destination "$DESTINATION" \
      $([[ "$PURE" == true ]] && echo "--pure") \
      --compression "$COMPRESSION" \
      --format "$FORMAT"; then
  echo "[INFO] Backup finished successfully."
  if [[ "$CHECK_USER" == true ]]; then
    mark_user_activity_backuped
    echo "[INFO] User activity marked as backuped."
  fi

else
  echo "[ERROR] Backup failed!"
  exit 1
fi

say "Backup ($BACKUP_MODE) completed successfully."
