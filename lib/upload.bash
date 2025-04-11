# upload.bash - upload files to device
# shellcheck shell=bash

# --- Public API ---
# upload_template
#
# Expects the following top-level variables:
#   - REMOTE_DIR path to templates folder on device.
#   - RMK_USER Name of the username to log into the device with (typically `root`)
#   - RMK_HOST IP address of the device

# shellcheck source=./util.bash
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/bootstrap.bash"

upload_template() {
  local svg_file="$1"
  local final_name="$2"
  log_info "Uploading '$svg_file' to '$REMOTE_DIR/${final_name}.svg'"
  scp "$svg_file" "$RMK_USER@$RMK_HOST:$REMOTE_DIR/${final_name}.svg"
  log_success "Template file (svg) uploaded."
}

upload_splash_screen() {
  local splash_file="$1"
  local remote_path
  local backup_path

  remote_path="/usr/share/remarkable/$(basename "$splash_file")"
  backup_path="$remote_path.bak"

  log_info "Uploading splash screen '$splash_file' to '$remote_path'"

  # shellcheck disable=SC2029
  ssh "$RMK_USER@$RMK_HOST" "if [ -f '$remote_path' ] && [ ! -f '$backup_path' ]; then cp '$remote_path' '$backup_path'; fi"

  scp "$splash_file" "$RMK_USER@$RMK_HOST:$remote_path"
  log_success "Splash screen uploaded to '$remote_path' (backup: $(basename "$backup_path"))"
}

relocate_templates_if_needed() {
  log_info "Checking if templates directory relocation is needed..."

  ssh "$1@$2" '
    set -e
    original="/usr/share/remarkable/templates"
    relocated="/home/root/templates"

    if [ -L "$original" ]; then
      echo "already-symlinked"
      exit 0
    fi

    if [ ! -d "$original" ]; then
      echo "missing-original"
      exit 1
    fi

    if [ -e "$relocated" ]; then
      echo "relocated-exists"
      exit 1
    fi

    echo "relocating"
    mv "$original" "$relocated"
    ln -s "$relocated" "$original"
    echo "done"
  ' | while read -r line; do
    case "$line" in
      already-symlinked)
        log_info "✔ Templates already relocated."
        ;;
      relocating)
        log_info "🔄 Relocating templates directory on device..."
        ;;
      done)
        log_success "✅ Templates successfully relocated and symlinked."
        ;;
      missing-original)
        log_error "❌ Error: Original templates directory does not exist."
        ;;
      relocated-exists)
        log_warn "⚠️ Warning: Target relocation directory already exists. Skipping."
        ;;
      *)
        log_info "$line"
        ;;
    esac
  done
}