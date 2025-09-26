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
# export PATH="$(dirname "$GZIP_BIN")":"$(dirname "$ZSTD_BIN")":"$(dirname "$PV_BIN")":"$(dirname "$DU_BIN")":"$(dirname "$BZIP2_BIN")":"$(dirname "$XZ_BIN")":"$PATH"



# Argument parsing
if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <color|format> <message...>"
  echo "Example: $0 red 'Server restarting soon!'"
  exit 1
fi

CODE_NAME="$1"
shift
MESSAGE="$*"

# Map color/format names to Minecraft § codes
case "$CODE_NAME" in
  # Colors
  black) CODE="§0" ;;
  dark_blue) CODE="§1" ;;
  dark_green) CODE="§2" ;;
  dark_aqua) CODE="§3" ;;
  dark_red) CODE="§4" ;;
  dark_purple) CODE="§5" ;;
  gold) CODE="§6" ;;
  gray) CODE="§7" ;;
  dark_gray) CODE="§8" ;;
  blue) CODE="§9" ;;
  green) CODE="§a" ;;
  aqua) CODE="§b" ;;
  red) CODE="§c" ;;
  light_purple|pink) CODE="§d" ;;
  yellow) CODE="§e" ;;
  white) CODE="§f" ;;

  # Bedrock-only extras
  minecoin_gold) CODE="§g" ;;
  material_quartz) CODE="§h" ;;
  material_iron) CODE="§i" ;;
  material_netherite) CODE="§j" ;;
  material_redstone) CODE="§m" ;;
  material_copper) CODE="§n" ;;
  material_gold) CODE="§p" ;;
  material_emerald) CODE="§q" ;;
  material_diamond) CODE="§s" ;;
  material_lapis) CODE="§t" ;;
  material_amethyst) CODE="§u" ;;

  # Formatting
  obfuscated) CODE="§k" ;;
  bold) CODE="§l" ;;
  strikethrough) CODE="§m" ;;
  underline) CODE="§n" ;;
  italic) CODE="§o" ;;
  reset) CODE="§r" ;;

  *)
    echo "Unknown code: $CODE_NAME"
    echo "Available colors: black, dark_blue, dark_green, dark_aqua, dark_red, dark_purple, gold, gray, dark_gray, blue, green, aqua, red, light_purple, yellow, white"
    echo "Formats: obfuscated, bold, strikethrough, underline, italic, reset"
    exit 1
    ;;
esac

FULL_MESSAGE="${CODE}${MESSAGE}§r"

# Send via RCON
exec $mcrcon_cmd "say $FULL_MESSAGE"
