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
TMUX_BIN="@TMUX_BIN@"


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
tmux_cmd="$TMUX_BIN"

# PATH extension 
# (only figured that out later if you add it here it can actually just use the bin)
# So you can easily just switch out the "*_cmd" with the "normal" name 
# Extend PATH with all injected binaries so we can call them directly
for bin in \
  "$RSYNC_BIN" \
  "$MCSTATUS_BIN" \
  "$MCRCON_BIN" \
  "$AWK_BIN" \
  "$TAR_BIN" \
  "$ZIP_BIN" \
  "$UNZIP_BIN" \
  "$GZIP_BIN" \
  "$ZSTD_BIN" \
  "$PV_BIN" \
  "$DU_BIN" \
  "$BZIP2_BIN" \
  "$XZ_BIN" \
  "$WC_BIN" \
  "$FIND_BIN" \
  "$TMUX_BIN"
  
do
  export PATH="$(dirname "$bin"):$PATH"
done




# Defaults
SOURCE=""
DESTINATION=""
COMPRESSION="gzip"
FORMAT="tar"
PURE=false

usage() {
  cat <<EOF
Usage: $0 --source <subfolder> --destination <path>
          [--compression <gzip|bzip2|xz|zstd>] [--format <tar|zip>] [--pure]

Options:
  --source        Subfolder under \$DATA_DIR to back up (required)
  --destination   Backup destination path (required)
  --compression   Compression method for tar archives (default: gzip)
  --format        Archive format: tar or zip (default: tar)
  --pure          Perform plain rsync copy without compression
  --help          Show this help
EOF
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)      SOURCE="$2"; shift 2;;
    --destination) DESTINATION="$2"; shift 2;;
    --compression) COMPRESSION="$2"; shift 2;;
    --format)      FORMAT="$2"; shift 2;;
    --pure)        PURE=true; shift 1;;
    --help)        usage;;
    *) echo "Unknown option: $1"; usage;;
  esac
done

# Validation
if [[ -z "$SOURCE" || -z "$DESTINATION" ]]; then
  echo "Error: --source and --destination are required."
  usage
fi

FULL_SOURCE="$DATA_DIR/$SOURCE"

if [[ ! -d "$FULL_SOURCE" ]]; then
  echo "Error: Source directory '$FULL_SOURCE' does not exist."
  exit 1
fi

mkdir -p "$DESTINATION"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BASENAME="$(basename "$SOURCE")"

# Pure rsync backup
if [[ "$PURE" == true ]]; then
  TARGET_DIR="$DESTINATION/${BASENAME}-${TIMESTAMP}"
  echo "Performing pure rsync backup to $TARGET_DIR"
  "$rsync_cmd" -rptgoDL --delete "$FULL_SOURCE/" "$TARGET_DIR/"
  echo "Backup completed (pure): $TARGET_DIR"
  exit 0
fi

# Archive/compression backup
case "$FORMAT" in
  tar)
    case "$COMPRESSION" in
      gzip)  EXT="tar.gz";  TAR_ARGS="-czf";;
      bzip2) EXT="tar.bz2"; TAR_ARGS="-cjf";;
      xz)    EXT="tar.xz";  TAR_ARGS="-cJf";;
      zstd)  EXT="tar.zst"; TAR_ARGS="--zstd -cf";;
      *) echo "Unsupported compression for tar: $COMPRESSION"; exit 1;;
    esac
    ARCHIVE="$DESTINATION/${BASENAME}-${TIMESTAMP}.${EXT}"
    "$tar_cmd" -C "$DATA_DIR" $TAR_ARGS "$ARCHIVE" "$SOURCE"
    ;;
  zip)
    EXT="zip"
    ARCHIVE="$DESTINATION/${BASENAME}-${TIMESTAMP}.${EXT}"
    (cd "$DATA_DIR" && "$zip_cmd" -r "$ARCHIVE" "$SOURCE")
    ;;
  *)
    echo "Unsupported format: $FORMAT"
    exit 1
    ;;
esac


echo "Backup completed: $ARCHIVE"
