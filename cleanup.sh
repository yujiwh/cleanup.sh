#!/usr/bin/env bash
# cleanup.sh — Safe VPS cleanup for Ubuntu/Debian
# Usage:
#   sudo bash cleanup.sh
# Options:
#   --keep-logs   Keep systemd journal logs (skip log vacuum)
#   --dry-run     Show commands without running them

set -euo pipefail

DRY_RUN=0
KEEP_LOGS=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --keep-logs) KEEP_LOGS=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[dry-run] $*"
  else
    echo "+ $*"
    eval "$@"
  fi
}

require_root() {
  if [[ $(id -u) -ne 0 ]]; then
    echo "Please run as root: sudo bash cleanup.sh" >&2
    exit 1
  fi
}

main() {
  require_root

  echo "=== Cleanup start: $(date -Is) ==="
  echo "Disk usage before:"
  df -h / | awk 'NR==1||NR==2{print}'
  echo

  echo "[1/5] Clean APT cache..."
  run "apt-get clean"
  run "apt-get autoclean -y"
  echo

  echo "[2/5] Remove unused packages..."
  run "apt-get autoremove -y"
  echo

  if [[ $KEEP_LOGS -eq 1 ]]; then
    echo "[3/5] Skipping journal log cleanup"
  else
    echo "[3/5] Vacuuming journal logs (keep 7 days)..."
    run "journalctl --vacuum-time=7d" || true
  fi
  echo

  echo "[4/5] Cleaning /tmp ..."
  run "rm -rf /tmp/*"
  echo

  echo "Disk usage after:"
  df -h / | awk 'NR==1||NR==2{print}'
  echo "=== Cleanup finished: $(date -Is) ==="
}

main "$@"
