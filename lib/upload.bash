# upload.bash - upload svg file to device
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

  if [[ "${DRY_RUN:-false}" == true ]]; then
    log_info "[dry-run] Would upload $svg_file to $REMOTE_DIR/${final_name}.svg"
  else
    log_info "Uploading '$svg_file' to '$REMOTE_DIR/${final_name}.svg'"
    scp "$svg_file" "$RMK_USER@$RMK_HOST:$REMOTE_DIR/${final_name}.svg"
    log_success "Template file (svg) uploaded."
  fi
}
