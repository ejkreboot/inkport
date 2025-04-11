# util.bash - misc helpers for logging, cleanup

log_info() { 
  if [[ "${DRY_RUN:-false}" == true ]]; then
    echo "[dry-run] ℹ️  $*" >&2;
  else
    echo "ℹ️  $*" >&2;
  fi
}

log_warn() { 
  if [[ "${DRY_RUN:-false}" == true ]]; then
    echo "[dry-run] ℹ️  $*" >&2;
  else
    echo "ℹ️  $*" >&2;
  fi
}

log_success () { 
  if [[ "${DRY_RUN:-false}" == true ]]; then
    echo "[dry-run] ✅ $*";
  else
    echo "✅  $*";
  fi
}

log_error() { 
  if [[ "${DRY_RUN:-false}" == true ]]; then
    echo "[dry-run] ❌   $*" >&2;
  else
    echo "❌  $*" >&2;
  fi
}

die()         { log_error "$@"; exit 1; }
