# tempjson.bash - handles templates.json patching
# --- Public API ---
# ensure_template_prefix
# lookup_icon_code
# generate_json_patch
# append_to_templates_json
#
# Expects the following top-level variables:
#   - ICONMAP_FILE path to the mappingn between human friendly name and unicode

# shellcheck source=./bootstrap.bash
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/bootstrap.bash"

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
  local hex_code

  [[ -z "${ICONMAP_FILE:-}" ]] && log_warn "Warning: ICONMAP_FILE is unset. Icon mapping may fail."

  if [[ "$friendly_name" == "blank" ]]; then
    printf "%s" "$friendly_name"
    return
  fi

  if [[ ! -f "$ICONMAP_FILE" ]]; then
    log_warn "Warning: $ICONMAP_FILE not found. Using raw value '$friendly_name'."
    printf "%s" "$friendly_name"
    return
  fi

  hex_code=$(jq -r --arg name "$friendly_name" '.[$name] // empty' "$ICONMAP_FILE")

  if [[ -z "$hex_code" ]]; then
    log_warn "Warning: Unknown icon '$friendly_name'. Using raw value." >&2
    printf "%s" "$friendly_name"
    return
  fi

  if [[ "$hex_code" =~ ^U\+([0-9A-Fa-f]{4,6})$ ]]; then
    local hex="${BASH_REMATCH[1]}"
    converted=$(printf "%08x" "0x$hex" | xxd -r -p | iconv -f UTF-32BE -t UTF-8 2>/dev/null) || true
    if [[ -z "$converted" ]]; then
      log_warn "Icon conversion failed. Using raw value '$friendly_name'."
      printf "%s" "$friendly_name"
    else
      printf "%s" "$converted"
    fi
  else
    log_warn "Warning: Malformed Unicode value '$hex_code'. Using raw fallback."
    printf "%s" "$hex_code"
  fi
}

generate_json_patch() {
  local template_name="$1"
  local display_name="$2"
  local orientation="$3"
  local icon="$4"
  local categories_json="$5"
  local filename icon_glyph

  filename=$(ensure_template_prefix "$template_name" "$orientation")
  icon_glyph=$(lookup_icon_code "$icon")

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
    log_error "Failed to generate updated template JSON."
    rm -f "$tmpfile.new"
    exit 1
  fi

  mv "$tmpfile.new" "$tmpfile"
}
