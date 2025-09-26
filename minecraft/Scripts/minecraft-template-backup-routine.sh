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

# PATH extension 
# (only figured that out later if you add it here it can actually just use the bin)
# So you can easily just switch out the "*_cmd" with the "normal" name 
export PATH="$(dirname "$GZIP_BIN")":"$(dirname "$ZSTD_BIN")":"$(dirname "$PV_BIN")":"$(dirname "$DU_BIN")":"$(dirname "$BZIP2_BIN")":"$(dirname "$XZ_BIN")":"$PATH"

# Defaults 
REBOOT=false
SLEEP_TIME=0
FULL=false
DESTINATION="/srv/minecraft/backups/unknown"
PURE=false
FORMAT="tar"
COMPRESSION="gzip"

# Usage 
usage() {
  cat <<EOF
Usage: $0 [--reboot] [--sleep <seconds>] [--full] [--destination <path>] [--pure]
          [--format <tar|zip>] [--compression <gzip|bzip2|xz|zstd>]

  --reboot        Stop server before backup and start afterwards [DOES NOT WORK]
  --sleep N       Wait N seconds with countdown announcements
  --full          Backup entire server directory (default: world only)
  --destination X Backup target directory (default: /srv/minecraft/backups/unknown)
  --pure          Use rsync to copy files (no compression, symlinks resolved)
  --format X      Archive format: tar or zip (ignored if --pure)
  --compression X Compression for tar (default: gzip)
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


do_backup() {
  #echo "[DEBUG] Entering do_backup with args: $*"
  local source=""
  local destination=""
  local compression="gzip"
  local format="tar"
  local pure=false
 
  # parse args
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --source)      source="$2"; shift 2 ;;
      --destination) destination="$2"; shift 2 ;;
      --compression) compression="$2"; shift 2 ;;
      --format)      format="$2"; shift 2 ;;
      --pure)        pure=true; shift ;;

      *) echo "[ERROR] Unknown option to do_backup: $1"; return 1 ;;
    esac
  done


  if [[ -z "$source" || -z "$destination" ]]; then
    echo "[ERROR] Missing --source or --destination"
    return 1
  fi

  local timestamp="$(date +%Y%m%d-%H%M%S)"
  local full_source="$DATA_DIR/$source"
  local basename="$(basename "$source")"
  local archive=""
  local ext=""


  if [[ ! -d "$full_source" ]]; then
    echo "[ERROR] Source directory not found: $full_source"
    return 1
  fi

  mkdir -p "$destination"

  if [[ "$pure" == true ]]; then
    local target_dir="$destination/${basename}-${timestamp}"
    echo "[INFO] Performing pure rsync backup to $target_dir"
    echo "#####"

    local last_percentage=-1

    "$rsync_cmd" -rptgoDL --delete --info=progress2 --stats \
        "$full_source/" "$target_dir/" 2>&1 | \
        while IFS= read -r -d $'\r' chunk; do
            # Extract percentage
            if [[ $chunk =~ ([0-9]{1,3})% ]]; then
                current_percentage=${BASH_REMATCH[1]}
                # Print only if percentage changed
                if [[ $current_percentage -ne $last_percentage ]]; then
                    echo -e "Progress: ${current_percentage}%\r" | say "$@"
                    last_percentage=$current_percentage
                fi
            fi
        done


    return 0
  fi

#echo "[DEBUG] Using archive mode: format=$format compression=$compression"
# Archive/compression backup 

case "$format" in
  tar)
    # Map compression → extension and tar invocation (using only *_cmd vars)
    case "$compression" in
      none)
        ext="tar"
        tar_create=( "$tar_cmd" -cvf )
        ;;
      gzip)
        ext="tar.gz"
        tar_create=( "$tar_cmd" --use-compress-program="$gzip_cmd" -cvf )
        ;;
      bzip2)
        ext="tar.bz2"
        tar_create=( "$tar_cmd" --use-compress-program="$bzip2_cmd" -cvf )
        ;;
      xz)
        ext="tar.xz"
        tar_create=( "$tar_cmd" --use-compress-program="$xz_cmd" -cvf )
        ;;
      zstd)
        ext="tar.zst"
        tar_create=( "$tar_cmd" --use-compress-program="$zstd_cmd" -cvf )
        ;;
      *)
        echo "[ERROR] Unsupported tar compression: $compression" >&2
        exit 1
        ;;
    esac

    archive="$destination/${basename}-${timestamp}.${ext}"
    sources=( $source )
    for s in "${sources[@]}"; do
      if [[ ! -e "$DATA_DIR/$s" ]]; then
        echo "[ERROR] Source not found under DATA_DIR: $DATA_DIR/$s" >&2
        exit 1
      fi
    done

    # Count total items for progress (files + dirs)
    total_items=0
    for s in "${sources[@]}"; do
      count=$(find "$DATA_DIR/$s" | wc -l)
      total_items=$(( total_items + count ))
    done
    current=0

    echo "[INFO] Creating $archive"

    last_percent=-1
    last_info_time=$(date +%s)
    # seconds between info logs
    interval=2

    (
      "${tar_create[@]}" "$archive" -C "$DATA_DIR" "${sources[@]}"
    ) 2>&1 | while read -r line; do
      if [[ -n "$line" ]]; then
        current=$(( current + 1 ))
        if (( total_items > 0 )); then
          percent=$(( current * 100 / total_items ))

          # echo full percent:
          #echo "[DEBUG] Progress: ${percent}%"
          now=$(date +%s)
          if (( percent != last_percent )) && (( now - last_info_time >= interval )); then
            #echo "[INFO] Progress: ${percent}%"
            say "Progress: ${percent}%" 
            last_percent=$percent
            last_info_time=$now
          fi
        fi
      fi
    done

    # Ensure 100% gets printed once at the end
    if (( last_percent < 100 )); then
      #echo "[INFO] Progress: 100%"
       say "Progress: 100%" 
    
    fi

    echo "[INFO] Tar archive created: $archive"
    ;;

  zip)
    ext="zip"
    archive="$destination/${basename}-${timestamp}.${ext}"
    echo "[INFO] Creating zip archive $archive"

    # Count both files and directories
    total_items=$(find "$DATA_DIR/$source" | wc -l)
    current=0

    last_percent=-1
    last_info_time=$(date +%s)
    interval=2   # seconds between info logs

    (
      cd "$DATA_DIR"
      "$zip_cmd" -r "$archive" "$source"
    ) 2>&1 | while read -r line; do
      if [[ $line =~ adding: ]]; then
        current=$((current+1))
        if (( total_items > 0 )); then
          percent=$(( current * 100 / total_items ))

          #echo "[DEBUG] Progress: ${percent}%"

          now=$(date +%s)
          if (( percent != last_percent )) && (( now - last_info_time >= interval )); then
            #echo "[INFO] Progress: ${percent}%"
            say "Progress: ${percent}%" 
            last_percent=$percent
            last_info_time=$now
          fi
        fi
      fi
    done

    # Ensure 100% gets printed once at the end
    if (( last_percent < 100 )); then
      #echo "[INFO] Progress: 100%"
       say "Progress: 100%"  
    fi

    echo "[INFO] Zip archive created: $archive"
    ;;

  *)
    echo "[ERROR] Unsupported format: $format"
    return 1
    ;;
esac

echo "[INFO] Backup completed: $archive"
return 0

}


# MAIN

#echo "[DEBUG] FULL=$FULL"

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
else
  echo "[ERROR] Backup failed!"
  exit 1
fi


say "Backup ($BACKUP_MODE) completed successfully."
