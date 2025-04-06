#!/bin/bash

# --- Configuration ---
LOCAL_DIR="$HOME/Documents/Remarkable"
ARCHIVE_DIR="$LOCAL_DIR/Uploaded"
REMARKABLE_CONFIG="$LOCAL_DIR/.remarkable"

DEFAULT_ICON="blank"
DEFAULT_ORIENTATION="portrait"
DEFAULT_CATEGORIES='["paper"]'

HOST="10.0.0.91"
USER="root"
REMOTE_DIR="/usr/share/remarkable/templates/"
JSON_PATH="$REMOTE_DIR/templates.json"
RETRY_INTERVAL=3600

TMPFILE=""

# --- Helper Functions ---

init_paths() {
  mkdir -p "$LOCAL_DIR/temp"
  TMPFILE=$(mktemp -p "$LOCAL_DIR/temp")
}

load_default_metadata() {
  local meta_file="$REMARKABLE_CONFIG/meta_default.json"
  if [ -f "$meta_file" ]; then
    echo "Loading defaults from $meta_file"
    DEFAULT_ICON=$(jq -r '.iconCode // "blank"' "$meta_file")
    DEFAULT_ORIENTATION=$(jq -r '.orientation // "portrait"' "$meta_file")
    DEFAULT_CATEGORIES=$(jq -c '.categories // ["paper"]' "$meta_file")
  fi
}

lookup_icon_code() {
  local friendly_name="$1"
  local icon_map_path="$REMARKABLE_CONFIG/iconMap.json"

  if [ ! -f "$icon_map_path" ]; then
    echo "Warning: iconMap.json not found. Using raw value '$friendly_name'." >&2
    printf "%s" "$friendly_name"
    return
  fi

  local hex_code=$(jq -r --arg name "$friendly_name" '.[$name] // empty' "$icon_map_path")

  if [[ -z "$hex_code" ]]; then
    echo "Warning: Unknown icon '$friendly_name'. Using raw value." >&2
    printf "%s" "$friendly_name"
    return
  fi

  if [[ "$hex_code" =~ ^U\+([0-9A-Fa-f]{4,6})$ ]]; then
    local hex="${BASH_REMATCH[1]}"
    printf "%08x" "0x$hex" | xxd -r -p | iconv -f UTF-32BE -t UTF-8
  else
    echo "Warning: Malformed Unicode value '$hex_code'. Using raw fallback." >&2
    printf "%s" "$hex_code"
  fi
}

ensure_template_prefix() {
  local name="$1"
  local orientation="$2"

  case "$name" in
    "P "* | "LS "*) echo "$name" ;;
    *)
      if [ "$orientation" = "landscape" ]; then
        echo "LS $name"
      else
        echo "P $name"
      fi
      ;;
  esac
}

update_templates_json() {
  local TEMPLATE_NAME="$1"
  local BACKUP="$TMPFILE.bak"
  local META_FILE="$LOCAL_DIR/${TEMPLATE_NAME}.json"

  local ICON="$DEFAULT_ICON"
  local ORIENTATION="$DEFAULT_ORIENTATION"
  local CATEGORIES="$DEFAULT_CATEGORIES"

  if [ -f "$META_FILE" ]; then
    echo "Loading per-template metadata from $META_FILE"
    ICON=$(jq -r --arg icon "$ICON" '.iconCode // $icon' "$META_FILE")
    ORIENTATION=$(jq -r --arg orientation "$ORIENTATION" '.orientation // $orientation' "$META_FILE")
    CATEGORIES=$(jq -c --argjson categories "$CATEGORIES" '.categories // $categories' "$META_FILE")
    mv "$META_FILE" "$ARCHIVE_DIR"
  fi

  local DISPLAY_NAME="$TEMPLATE_NAME"
  local FILENAME=$(ensure_template_prefix "$TEMPLATE_NAME" "$ORIENTATION")

  if jq -e --arg name "$FILENAME" '.templates[] | select(.filename == $name)' "$TMPFILE" > /dev/null; then
    echo "Template '$FILENAME' already exists."
    rm -f "$BACKUP"
    return
  fi

  local ICON_GLYPH=$(lookup_icon_code "$ICON")

  NEW_ENTRY=$(jq -n \
    --arg name "$DISPLAY_NAME" \
    --arg filename "$FILENAME" \
    --arg iconCode "$ICON_GLYPH" \
    --argjson categories "$CATEGORIES" \
    '{ name: $name, filename: $filename, iconCode: $iconCode, categories: $categories }')

  jq --argjson newTemplate "$NEW_ENTRY" '.templates += [$newTemplate]' "$TMPFILE" > "${TMPFILE}.new"

  if ! jq . "${TMPFILE}.new" > /dev/null; then
    echo "Error: Resulting JSON is invalid. Aborting."
    rm -f "$BACKUP" "${TMPFILE}.new"
    return 1
  fi

  mv "${TMPFILE}.new" "$TMPFILE"
}

sync_templates() {
  scp root@$HOST:$JSON_PATH "$TMPFILE"
  cp "$TMPFILE" "$TMPFILE.bak"

  for FILE in "$LOCAL_DIR"/*.svg; do
    [ -e "$FILE" ] || continue
    BASENAME=$(basename "$FILE")
    TEMPLATE_NAME="${BASENAME%.*}"

    # Load orientation (default or from meta)
    ORIENTATION="$DEFAULT_ORIENTATION"
    META_FILE="$LOCAL_DIR/${TEMPLATE_NAME}.json"
    if [ -f "$META_FILE" ]; then
      ORIENTATION=$(jq -r --arg orientation "$DEFAULT_ORIENTATION" '.orientation // $orientation' "$META_FILE")
    fi

    # Determine actual filename to use
    FINAL_NAME=$(ensure_template_prefix "$TEMPLATE_NAME" "$ORIENTATION")

    # Copy to device under correct name
    scp "$FILE" "$USER@$HOST:$REMOTE_DIR/${FINAL_NAME}.svg"

    update_templates_json "$TEMPLATE_NAME"
    mv "$FILE" "$ARCHIVE_DIR"
  done

  scp "$TMPFILE" "$USER@$HOST:$JSON_PATH"
  rm -f "$TMPFILE" "$TMPFILE.bak"
}

# --- Entrypoint ---

main() {
  init_paths
  load_default_metadata
  sync_templates
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
