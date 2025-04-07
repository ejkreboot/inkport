#!/usr/bin/env bats

setup() {
  export SCRIPT_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export CONFIG_DIR="$SCRIPT_DIR/tests/fixtures/.remarkable"
  mkdir -p "$CONFIG_DIR"

  cat > "$CONFIG_DIR/config.json" <<EOF
{
  "host": "10.0.0.91",
  "user": "root",
  "defaultIcon": "blank",
  "defaultOrientation": "portrait",
  "defaultCategories": ["paper"],
  "localDir": "~/Documents/Remarkable",
  "remoteDir": "/usr/share/remarkable/templates/"
}
EOF

  source "$SCRIPT_DIR/lib/config.bash"
}

@test "loads config values from config.json" {
  load_config
  echo !!!
  echo $REMOTE_DIR

  [ "$RMK_HOST" = "10.0.0.91" ]
  [ "$RMK_USER" = "root" ]
  [ "$DEFAULT_ICON" = "blank" ]
  [ "$DEFAULT_ORIENTATION" = "portrait" ]
  [[ "$DEFAULT_CATEGORIES" == *"paper"* ]]
  [[ "$LOCAL_DIR" == *"Documents/Remarkable" ]]
  [ "$REMOTE_DIR" == "/usr/share/remarkable/templates" ]
}

@test "overrides config host and user with flags" {
  RMK_HOST="example.com"
  RMK_USER="admin"

  load_config

  [ "$RMK_HOST" = "example.com" ]
  [ "$RMK_USER" = "admin" ]
}
