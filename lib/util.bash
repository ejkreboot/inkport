# util.bash - misc helpers for logging, cleanup

log() {
  local level="$1"
  shift
  printf "[%s] %s\n" "$level" "$*"
}

die() {
  log "ERROR" "$*"
  exit 1
}

debug() {
  [[ "${DEBUG:-false}" == true ]] && log "DEBUG" "$*"
}
