#!/bin/bash

# Local paths
LOCAL_DIR="$HOME/Documents/Remarkable"
ARCHIVE_DIR="$HOME/Documents/Remarkable/Uploaded"
DEFAULT_ICON="blank"
DEFAULT_ORIENTATION="portrait"
DEFAULT_CATEGORIES='["paper"]'
REMARKABLE_CONFIG="$LOCAL_DIR/.remarkable"

# Remote paths
HOST="10.0.0.91"  
USER="root"
REMOTE_DIR="/usr/share/remarkable/templates/"
JSON_PATH="$REMOTE_DIR/templates.json"
TMPFILE=$(mktemp -p $LOCAL_DIR/temp)

# how long to wait if upload fails (possibly because asleep or powered off)
RETRY_INTERVAL=3600  # seconds (1 hour)

if [ -f "$REMARKABLE_CONFIG/meta_default.json" ]; then
  echo "Loading defaults from .remarkable..."
  DEFAULT_ICON=$(jq -r '.iconCode // "blank"' "$REMARKABLE_CONFIG")
  DEFAULT_ORIENTATION=$(jq -r '.orientation // "portrait"' "$REMARKABLE_CONFIG")
  DEFAULT_CATEGORIES=$(jq -c '.categories // ["paper"]' "$REMARKABLE_CONFIG")
fi

# Download the latest templates.json from the device
scp root@$HOST:$JSON_PATH "$TMPFILE"
# Backup locally for safety
cp "$TMPFILE" "$BACKUP"

update_templates_json() {
  TEMPLATE_NAME="$1"
  BACKUP="$TMPFILE.bak"
  META_FILE="$LOCAL_DIR/${TEMPLATE_NAME}.json"

  # Start with directory-level defaults
  ICON="$DEFAULT_ICON"
  ORIENTATION="$DEFAULT_ORIENTATION"
  CATEGORIES="$DEFAULT_CATEGORIES"
  
  # Override with per-template .meta if it exists
  if [ -f "$META_FILE" ]; then
    echo "Loading per-template metadata from $META_FILE"
    ICON=$(jq -r --arg icon "$ICON" '.iconCode // $icon' "$META_FILE")
    ORIENTATION=$(jq -r --arg orientation "$ORIENTATION" '.orientation // $orientation' "$META_FILE")
    CATEGORIES=$(jq -c --argjson categories "$CATEGORIES" '.categories // $categories' "$META_FILE")
  fi

  # Check if it already exists
  if jq -e --arg name "$TEMPLATE_NAME" '.templates[] | select(.filename == $name)' "$TMPFILE" > /dev/null; then
    echo "Template '$TEMPLATE_NAME' already exists."
    rm "$TMPFILE" "$BACKUP"
    return
  fi

  # New entry JSON
  NEW_ENTRY=$(jq -n --arg name "$TEMPLATE_NAME" '
    {
      name: $name,
      filename: $name,
      iconCode: "blank",
      categories: ["paper"],
      orientation: "portrait"
    }
  ')

  # Append entry to the templates array
  jq --argjson newTemplate "$NEW_ENTRY" '.templates += [$newTemplate]' "$TMPFILE" > "${TMPFILE}.new"

  # Validate JSON before overwriting
  if ! jq . "${TMPFILE}.new" > /dev/null; then
    echo "Error: Resulting JSON is invalid. Aborting."
    rm "$TMPFILE" "$BACKUP" "${TMPFILE}.new"
    return 1
  fi

  #get ready for next template, if any
  mv "${TMPFILE}.new" "${TMPFILE}"
}

lookup_icon_code() {
  local friendly_name="$1"
  local icon_map_path="$REMARKABLE_CONFIG/iconMap.json"

  if [ ! -f "$icon_map_path" ]; then
    echo "Warning: iconMap.json not found. Using raw value '$friendly_name'."
    printf "$friendly_name"
    return
  fi

  local hex_code=$(jq -r --arg name "$friendly_name" '.[$name] // empty' "$icon_map_path")

  if [[ -z "$hex_code" ]]; then
    echo "Warning: Unknown icon '$friendly_name'. Using raw value."
    printf "$friendly_name"
    return
  fi

  # Convert U+XXXX to actual Unicode char
  printf "$(echo "$hex_code" | sed 's/U+//' | xargs printf '\\U%08x\n')" | iconv -f UTF-32BE -t UTF-8
}

for FILE in "$LOCAL_DIR"/*.svg; do
  [ -e "$FILE" ] || continue
  BASENAME=$(basename "$FILE")
  TEMPLATE_NAME="${BASENAME%.*}"
  scp "$FILE" "$USER@$HOST:$REMOTE_DIR"
  update_templates_json "$TEMPLATE_NAME"
  mv "$FILE" "$ARCHIVE_DIR"
done

scp "${TMPFILE}" $USER@$HOST:$JSON_PATH
rm "$TMPFILE" "$BACKUP"
