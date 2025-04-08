#!/usr/bin/env bash
# bootstrap.bash - shared environment setup for modules

# Prevent re-sourcing
[[ -n "${BOOTSTRAPPED:-}" ]] && return
BOOTSTRAPPED=1

# Resolve script and project paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_DIR="$PROJECT_ROOT/.remarkable"
# shellcheck disable=SC2034
CONFIG_FILE="$CONFIG_DIR/config.json"
# shellcheck disable=SC2034
ICONMAP_FILE="$CONFIG_DIR/iconmap.json"

# shellcheck source=./util.bash
# shellcheck disable=SC1091
source "$SCRIPT_DIR/util.bash"

# Bash version check
if [[ "${BASH_VERSINFO:-0}" -lt 3 ]]; then
  die "Bash 3+ is required to run this script."
fi
