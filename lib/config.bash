# config.bash - parse args, load config

load_config() {
  CONFIG_DIR="$SCRIPT_DIR/.remarkable"
  CONFIG_FILE="$CONFIG_DIR/config.json"
  ICONMAP_FILE="$CONFIG_DIR/iconmap.json"

  if [[ -f "$CONFIG_FILE" ]]; then
    RMK_HOST=${RMK_HOST:-$(jq -r '.host' "$CONFIG_FILE")}
    RMK_USER=${RMK_USER:-$(jq -r '.user' "$CONFIG_FILE")}
    DEFAULT_ICON=$(jq -r '.defaultIcon // "blank"' "$CONFIG_FILE")
    DEFAULT_ORIENTATION=$(jq -r '.defaultOrientation // "portrait"' "$CONFIG_FILE")
    DEFAULT_CATEGORIES=$(jq -c '.defaultCategories // ["paper"]' "$CONFIG_FILE")
    LOCAL_DIR=$(eval echo $(jq -r '.localDir // "~/Documents/Remarkable"' "$CONFIG_FILE"))
    REMOTE_DIR=$(jq -r '.remoteDir // "/usr/share/remarkable/templates"' "$CONFIG_FILE")
    JSON_PATH="$REMOTE_DIR/templates.json"
  else
    echo "❌ Config file not found at $CONFIG_FILE"
    exit 1
  fi
}

parse_args() {
  while getopts ":n:i:c:h:u:dz" opt; do
    case $opt in
      n) DISPLAY_NAME="$OPTARG" ;;
      i) ICON="$OPTARG" ;;
      c) CATEGORY="$OPTARG" ;;
      h) RMK_HOST="$OPTARG" ;;
      u) RMK_USER="$OPTARG" ;;
      d) DRY_RUN=true ;;
      z) RESTORE_MODE=true ;;
      *) echo "Invalid option: -$OPTARG" >&2 ;;
    esac
  done
  shift $((OPTIND -1))

  if [[ "$RESTORE_MODE" != "true" ]]; then
    TEMPLATE_SVG="$1"
    META_FILE="${2:-}"
    if [[ -z "$TEMPLATE_SVG" ]]; then
      echo "❌ Missing required argument: TEMPLATE_SVG" >&2
      exit 1
    fi
  fi
}
