# tempjson.bash - handles templates.json patching

ensure_template_prefix() {
  local name="$1"
  local orientation="$2"

  case "$name" in
    "P "* | "LS "*) echo "$name" ;;
    *)
      if [[ "$orientation" == "landscape" ]]; then
        echo "LS $name"
      else
        echo "P $name"
      fi
      ;;
  esac
}

lookup_icon_code() {
  local friendly_name="$1"

  if [[ "$friendly_name" == "blank" ]]; then
    printf "$friendly_name"
    return
  fi

  if [[ ! -f "$ICONMAP_FILE" ]]; then
    echo "Warning: $ICONMAP_FILE not found. Using raw value '$friendly_name'." >&2
    printf "%s" "$friendly_name"
    return
  fi

  local hex_code=$(jq -r --arg name "$friendly_name" '.[$name] // empty' "$ICONMAP_FILE")

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

generate_json_patch() {
  local template_name="$1"
  local display_name="$2"
  local orientation="$3"
  local icon="$4"
  local categories_json="$5"

  local filename=$(ensure_template_prefix "$template_name" "$orientation")
  local icon_glyph=$(lookup_icon_code "$icon")

  jq -n \
    --arg name "$display_name" \
    --arg filename "$filename" \
    --arg iconCode "$icon_glyph" \
    --argjson categories "$categories_json" \
    '{ name: $name, filename: $filename, iconCode: $iconCode, categories: $categories }'
}

append_to_templates_json() {
  local patch_json="$1"
  local tmpfile="$2"

  jq --argjson newTemplate "$patch_json" '.templates += [$newTemplate]' "$tmpfile" > "$tmpfile.new" || exit 1
  
  if ! jq . "$tmpfile.new" > /dev/null; then
    echo "Error: Resulting JSON is invalid. Aborting."
    rm -f "$tmpfile.new"
    exit 1
  fi

  mv "$tmpfile.new" "$tmpfile"
}
