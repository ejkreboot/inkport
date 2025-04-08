# device.bash - handles OS version, backup, and restore
# shellcheck shell=bash

# --- Public API ---
# ensure_backup_exists
# restore_templates
#
# Expects the following top-level variables:
#   - REMOTE_DIR: path to the templates folder on the reMarkable device
#   - RMK_USER, RMK_HOST: SSH target
#   - OS_VERSION: current rM OS version

# shellcheck source=./bootstrap.bash
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/bootstrap.bash"
MIN_SUPPORTED_VERSION="3.18.1.1"

ensure_backup_exists() {
  local version="$OS_VERSION"
  local backup_path="$REMOTE_DIR/.restore/$version"
  log_info "Checking backup folder: $backup_path"
  # shellcheck disable=SC2029
  ssh "$RMK_USER@$RMK_HOST" "test -d '$backup_path' || (mkdir -p '$backup_path' && cp $REMOTE_DIR/* '$backup_path/')"
}

restore_templates() {
  local version="$OS_VERSION"
  local backup_path="$REMOTE_DIR/.restore/$version"
  log_info "Restoring templates.json from $backup_path..."
  # shellcheck disable=SC2029
  ssh "$RMK_USER@$RMK_HOST" "cp '$backup_path/templates.json' $REMOTE_DIR/templates.json"
  log_success "Templates restored to factory defaults for OS $version."
}

check_version() {
  OS_VERSION="$(fetch_os_version)"
  if ! version_ge "$OS_VERSION" "$MIN_SUPPORTED_VERSION"; then
    die "Remarkable OS version must be >= $MIN_SUPPORTED_VERSION"
  fi
}

# internal functions 

version_to_sortable() {
  local -a ver
  IFS=. read -ra ver <<< "$1"
  printf "%03d%03d%03d%03d" "${ver[@]}"
}

version_ge() {
  local ver1 ver2 
  ver1=$(version_to_sortable "$1" )
  ver2=$(version_to_sortable "$2" )
  [ "$ver1" -ge "$ver2" ]
}

fetch_os_version() {
  ssh "$RMK_USER@$RMK_HOST" 'grep REMARKABLE_RELEASE_VERSION /usr/share/remarkable/update.conf | cut -d= -f2'
}

