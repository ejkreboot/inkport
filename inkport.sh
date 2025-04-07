#!/bin/bash

# inkport.sh - main entrypoint

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"

# Load modules
source "$SCRIPT_DIR/lib/config.bash"
source "$SCRIPT_DIR/lib/device.bash"
source "$SCRIPT_DIR/lib/upload.bash"
source "$SCRIPT_DIR/lib/tempjson.bash"
source "$SCRIPT_DIR/lib/util.bash"

main() {
  parse_args "$@"
  load_config

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
  CATEGORIES_JSON="$DEFAULT_CATEGORIES"
  
  TMPFILE=$(mktemp -p $SCRIPT_DIR/temp)

  if [[ -f "$META_FILE" ]]; then
    ORIENTATION=$(jq -r --arg orientation "$DEFAULT_ORIENTATION" '.orientation // $orientation' "$META_FILE")
    ICON=$(jq -r --arg icon "$ICON" '.iconCode // $icon' "$META_FILE")
    CATEGORIES_JSON=$(jq -c --argjson fallback "$DEFAULT_CATEGORIES" '.categories // $fallback' "$META_FILE")
  fi
  
  if [[ -n "${CATEGORY:-}" ]]; then
    CATEGORIES_JSON=$(jq -nc --arg cat "$CATEGORY" '[$cat]')
  fi

  if [[ "${DRY_RUN:-false}" == true ]]; then
    OS_VERSION=0.0.0.0
    echo [dry-run] Here are the commands that would be executed:

    echo 
    echo [dry-run] backup default templates if not done previously
    echo ensure_backup_exists "$OS_VERSION"

    echo 
    echo [dry-run] download current template.json and make a backup
    echo scp "$RMK_USER@$RMK_HOST:$JSON_PATH" "$TMPFILE"
    echo cp "$TMPFILE" "$TMPFILE.bak"
    
    echo 
    echo [dry-run] normalize name and upload template file
    FINAL_NAME=$(ensure_template_prefix "$TEMPLATE_NAME" "$ORIENTATION")
    echo upload_template "$TEMPLATE_SVG" "$FINAL_NAME"

    echo 
    echo [dry-run] add to template.json
    PATCH=$(generate_json_patch "$TEMPLATE_NAME" "$DISPLAY_NAME" "$ORIENTATION" "$ICON" "$CATEGORIES_JSON")
    append_to_templates_json "$PATCH" "$TMPFILE"

    echo
    echo [dry-run] generated patch:
    echo $PATCH

    echo 
    echo [dry-run] copy template.json back up to device
    echo scp "$TMPFILE" "$RMK_USER@$RMK_HOST:$JSON_PATH"

    echo [dry-run] done

  else
    check_version

    if [[ "${RESTORE_MODE:-false}" == true ]]; then
      restore_templates "$OS_VERSION"
      exit 0
    fi

    scp "$RMK_USER@$RMK_HOST:$JSON_PATH" "$TMPFILE"
    cp "$TMPFILE" "$TMPFILE.bak"

    FINAL_NAME=$(ensure_template_prefix "$TEMPLATE_NAME" "$ORIENTATION")
    upload_template "$TEMPLATE_SVG" "$FINAL_NAME"

    PATCH=$(generate_json_patch "$TEMPLATE_NAME" "$DISPLAY_NAME" "$ORIENTATION" "$ICON" "$CATEGORIES_JSON")
    append_to_templates_json "$PATCH" "$TMPFILE"

    echo "⬆️ Uploading updated templates.json"
    scp "$TMPFILE" "$RMK_USER@$RMK_HOST:$JSON_PATH"

    # rm -f "$TMPFILE" "$TMPFILE.bak"
    echo "✅ Template '$FINAL_NAME' installed successfully. Restart your device to see new template."
  fi

}

main "$@"