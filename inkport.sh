#!/bin/bash
# inkport.sh - main entrypoint
# shellcheck shell=bash

set -euo pipefail

DRY_RUN=false
RESTORE_MODE=false

usage() {
  echo "Usage: $0 [-n name] [-i icon] [-c category] [-h host] [-u user] [-d] [-z] [TEMPLATE_SVG] [META_FILE]"
  exit 1
}

load_config_defaults() {
  ICON=${ICON:-$(jq -r '.defaultIcon // "blank"' "$CONFIG_FILE")}
  ORIENTATION=${ORIENTATION:-$(jq -r '.defaultOrientation // "portrait"' "$CONFIG_FILE")}
  CATEGORY=${CATEGORY:-$(jq -r '.defaultCategories[0] // "paper"' "$CONFIG_FILE")}
  LOCAL_DIR=$(eval echo "$(jq -r '.localDir // "~/Documents/Remarkable"' "$CONFIG_FILE")")
  REMOTE_DIR=$(jq -r '.remoteDir // "/usr/share/remarkable/templates"' "$CONFIG_FILE")
  JSON_PATH="$REMOTE_DIR/templates.json"
}

while getopts ":n:i:c:h:u:dz" opt; do
  case $opt in
    n) DISPLAY_NAME="$OPTARG" ;;
    i) ICON="$OPTARG" ;;
    c) CATEGORY="$OPTARG" ;;
    h) RMK_HOST="$OPTARG" ;;
    u) RMK_USER="$OPTARG" ;;
    d) DRY_RUN=true ;;
    z) RESTORE_MODE=true ;;
    *) echo "Invalid option: -$OPTARG" >&2; usage ;;
  esac
done
shift $((OPTIND -1))

if $RESTORE_MODE; then
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
source "$SCRIPT_DIR/lib/device.bash"
# shellcheck source=./lib/upload.bash
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/upload.bash"
# shellcheck source=./lib/tempjson.bash
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/tempjson.bash"
# shellcheck source=./lib/util.bash
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/util.bash"

main() {
  local BASENAME TEMPLATE_NAME FINAL_NAME TMPFILE PATCH

  if [[ -z "${RMK_HOST:-}" || -z "${RMK_USER:-}" ]]; then
    die "Missing SSH host or user. Set via config or -h/-u flags."
  fi

  if [[ ! -f "$TEMPLATE_SVG" ]]; then
    die "SVG file not found: $TEMPLATE_SVG"
  fi

  BASENAME=$(basename "$TEMPLATE_SVG")
  TEMPLATE_NAME="${BASENAME%.*}"
  DISPLAY_NAME="${DISPLAY_NAME:-$TEMPLATE_NAME}"

  # Metadata defaults
  META_FILE="${META_FILE:-$SCRIPT_DIR/${TEMPLATE_NAME}.json}"
  ICON="${ICON:-$DEFAULT_ICON}"
  ORIENTATION="$DEFAULT_ORIENTATION"
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

  if [[ "${DRY_RUN:-false}" == true ]]; then
    OS_VERSION=0.0.0.0
    dry_run

  else
    check_version

    if [[ "${RESTORE_MODE:-false}" == true ]]; then
      restore_templates "$OS_VERSION"
      exit 0
    fi

    scp "$RMK_USER@$RMK_HOST:$JSON_PATH" "$TMPFILE"
    cp "$TMPFILE" "$TMPFILE.bak"

    upload_template "$TEMPLATE_SVG" "$FINAL_NAME"
    append_to_templates_json "$PATCH" "$TMPFILE"

    echo "⬆️ Uploading updated templates.json"
    scp "$TMPFILE" "$RMK_USER@$RMK_HOST:$JSON_PATH"

    rm -f "$TMPFILE" "$TMPFILE.bak"
    echo "✅ Template '$FINAL_NAME' installed successfully. Restart your device to see new template."
  fi

}

main "$@"

dry_run() {
  echo "[dry-run] Here are the commands that would be executed:"

  echo 
  echo "[dry-run] backup default templates if not done previously"
  echo ensure_backup_exists "$OS_VERSION"

  echo 
  echo "[dry-run] download current template.json and make a backup"
  echo scp "$RMK_USER@$RMK_HOST:$JSON_PATH" "$TMPFILE"
  echo cp "$TMPFILE" "$TMPFILE.bak"
  
  echo 
  echo "[dry-run] normalize name and upload template file"
  FINAL_NAME=$(ensure_template_prefix "$TEMPLATE_NAME" "$ORIENTATION")
  echo upload_template "$TEMPLATE_SVG" "$FINAL_NAME"

  echo 
  echo "[dry-run] add to template.json"
  PATCH=$(generate_json_patch "$TEMPLATE_NAME" "$DISPLAY_NAME" "$ORIENTATION" "$ICON" "$CATEGORIES_JSON")
  append_to_templates_json "$PATCH" "$TMPFILE"

  echo
  echo "[dry-run] generated patch:"
  echo "$PATCH"

  echo 
  echo "[dry-run] copy template.json back up to device"
  echo scp "$TMPFILE" "$RMK_USER@$RMK_HOST:$JSON_PATH"

  echo "[dry-run] done"
}

to_json_array() {
  jq -nc --arg val "$1" '$val | split(" ") | map(select(. != ""))'
}