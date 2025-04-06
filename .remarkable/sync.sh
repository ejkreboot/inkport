#!/bin/bash

# Path to local folder
LOCAL_DIR="$HOME/Documents/Remarkable"

# Path to remote template folder on reMarkable
REMOTE_DIR="/usr/share/remarkable/templates/"
ARCHIVE_DIR="$HOME/Documents/Remarkable/Uploaded"
USER="root"
HOST="10.0.0.91"  
RETRY_INTERVAL=3600  # seconds (1 hour)
TMPFILE=$(mktemp -p $LOCAL_DIR/temp)
JSON_PATH="/usr/share/remarkable/templates/templates.json"

# Download the latest templates.json from the device
scp root@$HOST:$JSON_PATH "$TMPFILE"

update_templates_json() {
  TEMPLATE_NAME="$1"
  BACKUP="$TMPFILE.bak"

  # Pull latest version from device
  scp root@$HOST:$JSON_PATH "$TMPFILE"

  # Backup locally for safety
  cp "$TMPFILE" "$BACKUP"

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
  local icon_map_path="$LOCAL_DIR/.remarkable/iconMap.json"

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

