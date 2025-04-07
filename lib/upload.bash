# device.bash - handles OS version, backup, and restore

upload_template() {
  local svg_file="$1"
  local final_name="$2"

  if [[ "${DRY_RUN:-false}" == true ]]; then
    echo "[dry-run] Would upload $svg_file to $REMOTE_DIR/${final_name}.svg"
  else
    echo "🚀 Uploading $svg_file to $REMOTE_DIR/${final_name}.svg"
    scp "$svg_file" "$USER@$HOST:$REMOTE_DIR/${final_name}.svg"
  fi
}
