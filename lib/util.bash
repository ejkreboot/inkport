# util.bash - misc helpers for logging, cleanup

log_info()    { echo "ℹ️  $*"; }
log_success() { echo "✅ $*"; }
log_warn()    { echo "⚠️  $*" >&2; }
log_error()   { echo "❌ $*" >&2; }
die()         { log_error "$@"; exit 1; }
