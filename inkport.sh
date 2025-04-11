#!/bin/bash
# inkport.sh - main entrypoint
# shellcheck shell=bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=./lib/device.bash
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/bootstrap.bash"

DRY_RUN=false
RESTORE_MODE=false
SHOW_HELP=false
UPLOAD_SPLASH=false

usage() {
  echo "Usage: $0 [-n name] [-i icon] [-c category] [-h host] [-u user] [-d] [-z] [TEMPLATE_SVG] [META_FILE]"
  echo
  echo "Options:"
  echo "  -n NAME       Set display name"
  echo "  -i ICON       Set icon code (default: from config or 'blank')"
  echo "  -c CATEGORY   Set category (default: from config or 'paper')"
  echo "  -h HOST       Set SSH host"
  echo "  -u USER       Set SSH username (default: root)"
  echo "  -s FILE       Upload splash screen file"
  echo "  -d            Dry run"
  echo "  -z            Restore mode"
  echo "  -?            Show this help message"
  exit 0
}

load_config_defaults() {
  ICON=${ICON:-$(jq -r '.defaultIcon // "blank"' "$CONFIG_FILE")}
  ORIENTATION=${ORIENTATION:-$(jq -r '.defaultOrientation // "portrait"' "$CONFIG_FILE")}
  CATEGORY=${CATEGORY:-$(jq -r '.defaultCategories[0] // "paper"' "$CONFIG_FILE")}
  LOCAL_DIR=$(eval echo "$(jq -r '.localDir // "~/Documents/Remarkable"' "$CONFIG_FILE")")
  REMOTE_DIR=$(jq -r '.remoteDir // "/usr/share/remarkable/templates"' "$CONFIG_FILE")
  JSON_PATH="$REMOTE_DIR/templates.json"
}

while getopts ":n:i:c:h:u:dzs:?" opt; do
  case $opt in
    n) DISPLAY_NAME="$OPTARG" ;;
    i) ICON="$OPTARG" ;;
    c) CATEGORY="$OPTARG" ;;
    h) RMK_HOST="$OPTARG" ;;
    u) RMK_USER="$OPTARG" ;;
    d) DRY_RUN=true ;;
    s) UPLOAD_SPLASH=true; SPLASH_FILE="$OPTARG" ;;
    z) RESTORE_MODE=true ;;
    ?) SHOW_HELP=true ;;
    *) echo "Invalid option: -$OPTARG" >&2; usage ;;
  esac
done
shift $((OPTIND -1))

if $SHOW_HELP; then
  usage
fi

if [[ "$UPLOAD_SPLASH" == true ]]; then
  if [[ -z "$SPLASH_FILE" ]]; then
    die "Error: -s flag used but no file provided." >&2
  fi

  if [[ ! -f "$SPLASH_FILE" ]]; then
    die "Error: splash screen file '$SPLASH_FILE' not found." >&2
  fi

  upload_splash_screen "$SPLASH_FILE"
  exit 0
fi


if [[ "${RESTORE_MODE:-false}" == true ]]; then 
  restore_templates;
  log_success Original templates restored.
  exit 0
else
  TEMPLATE_SVG="${1:-}"
  META_FILE="${2:-}"
  if [[ -z "$TEMPLATE_SVG" ]]; then
    echo "Missing required argument: TEMPLATE_SVG" >&2
    exit 1
  fi
fi

# Load config file and/or set default values
if [[ -f "$CONFIG_FILE" ]]; then
  RMK_HOST=${RMK_HOST:-$(jq -r '.host' "$CONFIG_FILE")}
  RMK_USER=${RMK_USER:-$(jq -r '.user' "$CONFIG_FILE")}
  load_config_defaults
  echo !!!!!!!
  echo "$CONFIG_FILE"
  echo "$RMK_HOST"
else
  if [[ -z "${RMK_HOST:-}" ]]; then
    echo "Error: Remote host not found in config file and not provided with -h flag."
    exit 1
  fi
  RMK_USER=${RMK_USER:-"root"}
  ICON=${ICON:-"blank"}
  ORIENTATION="portrait"
  CATEGORY=${CATEGORY:-"paper"}
  # shellcheck disable=SC2034
  LOCAL_DIR="$HOME/Documents/Remarkable"
  REMOTE_DIR="/usr/share/remarkable/templates"
  JSON_PATH="$REMOTE_DIR/templates.json"
fi

# Load modules
# shellcheck source=./lib/device.bash
# shellcheck disable=SC1091
source "$SCRIPT_DIR/device.bash"
# shellcheck source=./lib/upload.bash
# shellcheck disable=SC1091
source "$SCRIPT_DIR/upload.bash"
# shellcheck source=./lib/tempjson.bash
# shellcheck disable=SC1091
source "$SCRIPT_DIR/tempjson.bash"
# shellcheck source=./lib/util.bash
# shellcheck disable=SC1091
source "$SCRIPT_DIR/util.bash"

main() {
  local BASENAME TEMPLATE_NAME FINAL_NAME TMPFILE PATCH

  if [[ -z "${RMK_HOST:-}" || -z "${RMK_USER:-}" ]]; then
    die "Missing SSH host or user. Set via config or -h/-u flags."
  fi

  if [[ ! -f "$TEMPLATE_SVG" ]]; then
    die "SVG file not found: $TEMPLATE_SVG"
  fi

  if [[ "${DRY_RUN:-false}" == true ]]; then
    # use mock'ed ssh and scp to just simulate what would happen if this was 
    # not a drill.
    echo !!! "$SCRIPT_DIR/dryrun"
    export PATH="$SCRIPT_DIR/dryrun:$PATH"
    log_info "Dry-run mode: using mock file system and SSH commands"
  fi

  BASENAME=$(basename "$TEMPLATE_SVG")
  TEMPLATE_NAME="${BASENAME%.*}"
  DISPLAY_NAME="${DISPLAY_NAME:-$TEMPLATE_NAME}"

  # Metadata defaults
  META_FILE="${META_FILE:-$SCRIPT_DIR/${TEMPLATE_NAME}.json}"
  ICON="${ICON:-$DEFAULT_ICON}"
  TMPFILE=$(mktemp -p "$SCRIPT_DIR/temp")
  CATEGORY="${CATEGORY:-$DEFAULT_CATEGORY}"  # raw string

  if [[ -f "$META_FILE" ]]; then
    ORIENTATION=$(jq -r --arg orientation "$DEFAULT_ORIENTATION" '.orientation // $orientation' "$META_FILE")
    ICON=$(jq -r --arg icon "$ICON" '.iconCode // $icon' "$META_FILE")

    META_CATEGORY=$(jq -c '.categories' "$META_FILE")
    if [[ "$META_CATEGORY" != "null" ]]; then
      CATEGORIES_JSON="$META_CATEGORY"
    fi
  fi

  # If user passed -c, override category list from meta file
  if [[ -n "${CATEGORY:-}" ]]; then
    CATEGORIES_JSON=$(to_json_array "$CATEGORY")
  elif [[ -z "${CATEGORIES_JSON:-}" ]]; then
    CATEGORIES_JSON=$(to_json_array "$DEFAULT_CATEGORY")
  fi

  FINAL_NAME=$(ensure_template_prefix "$TEMPLATE_NAME" "$ORIENTATION")
  PATCH=$(generate_json_patch "$TEMPLATE_NAME" "$DISPLAY_NAME" "$ORIENTATION" "$ICON" "$CATEGORIES_JSON")

  check_version

  if [[ "${RESTORE_MODE:-false}" == true ]]; then
    restore_templates "$OS_VERSION"
    exit 0
  fi

  relocate_templates_if_needed "$RMK_USER" "$RMK_HOST"

  scp "$RMK_USER@$RMK_HOST:$JSON_PATH" "$TMPFILE"
  cp "$TMPFILE" "$TMPFILE.bak"

  upload_template "$TEMPLATE_SVG" "$FINAL_NAME"
  append_to_templates_json "$PATCH" "$TMPFILE"

  echo "⬆️ Uploading updated templates.json"
  scp "$TMPFILE" "$RMK_USER@$RMK_HOST:$JSON_PATH"

  rm -f "$TMPFILE" "$TMPFILE.bak"
  echo "✅ Template '$FINAL_NAME' installed successfully. Restart your device to see new template."
}

to_json_array() {
  jq -nc --arg val "$1" '$val | split(" ") | map(select(. != ""))'
}

main "$@"

