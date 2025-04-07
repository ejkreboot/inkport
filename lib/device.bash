# device.bash - handles OS version, backup, and restore
MIN_SUPPORTED_VERSION="3.18.1.1"

ver_to_num() {
  local -a ver
  IFS=. read -ra ver <<< "$1"
  printf "%03d%03d%03d%03d" "${ver[@]}"
}

semver_ge() {
  local ver1=$(ver_to_num $1 )
  local ver2=$(ver_to_num $2 )
  if [ $ver1 -lt $ver2 ]; then 
    return 1
  fi
  return 0
}

fetch_os_version() {
  ssh "$RMK_USER@$RMK_HOST" 'grep REMARKABLE_RELEASE_VERSION /usr/share/remarkable/update.conf | cut -d= -f2'
}

check_version() {
  OS_VERSION=$(fetch_os_version)
  echo "Detected reMarkable OS version: $OS_VERSION"
  if ! semver_ge "$OS_VERSION" "$MIN_SUPPORTED_VERSION"; then
    echo "❌ reMarkable OS version must be >= $MIN_SUPPORTED_VERSION"
    exit 1
  fi
}

ensure_backup_exists() {
  local version="$OS_VERSION"
  local backup_path="/usr/share/remarkable/templates/.restore/$version"
  echo "🗂️  Checking backup folder: $backup_path"
  ssh "$RMK_USER@$RMK_HOST" "test -d '$backup_path' || (mkdir -p '$backup_path' && cp /usr/share/remarkable/templates/* '$backup_path/')"
}

restore_templates() {
  local version="$OS_VERSION"
  local backup_path="/usr/share/remarkable/templates/.restore/$version"
  echo "🔁 Restoring templates.json from $backup_path..."
  ssh "$RMK_USER@$RMK_HOST" "cp '$backup_path/templates.json' /usr/share/remarkable/templates/templates.json"
  echo "✅ Templates restored to factory defaults for OS $version."
}

