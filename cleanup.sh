#!/usr/bin/env bash
#============================================================================
# cleanup.sh — Advanced VPS Cleanup for Debian/Ubuntu
# Version   : 2.0.0
#
# Copyright (c) 2026 YujiWH. All rights reserved.
# Author  : yujiwh <yujiwh@yujiwh.xyz>
# License : MIT
# Source  : https://github.com/yujiwh/cleanup.sh
#
# Disclaimer: This script is provided "as is", without warranty.
# Use at your own risk. Always backup critical data before cleanup.
#============================================================================
# Usage:
#   sudo bash cleanup.sh                    # interactive (ask per step)
#   sudo bash cleanup.sh --full             # full auto-clean (skip docker)
#   sudo bash cleanup.sh --full --docker    # full + docker prune
#   sudo bash cleanup.sh --dry-run          # see what would be freed
#   sudo bash cleanup.sh --keep-logs        # skip journal cleanup
#   sudo bash cleanup.sh --report           # only check, no cleanup
#   sudo bash cleanup.sh --output report.log # save report to file
#============================================================================

set -euo pipefail

# ─── Config ────────────────────────────────────────────────────────────────
DRY_RUN=0
FULL_MODE=0
SKIP_DOCKER=1   # default: skip docker unless --docker
DO_DOCKER=0
KEEP_LOGS=0
SHOW_REPORT=0
OUTPUT_FILE=""
JOURNAL_SIZE="50M"       # keep only 50MB journal
JOURNAL_DAYS="7"         # keep 7 days
TMP_DAYS="+7"            # delete files in /tmp older than 7 days
LARGE_FILE_THRESHOLD="100M"

# For summary
declare -a FREED_ITEMS
START_USED=""
END_USED=""
START_AVAIL=""
END_AVAIL=""

# ─── Colors ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ─── Parse args ─────────────────────────────────────────────────────────────
for arg in "$@"; do
  case "$arg" in
    --dry-run)     DRY_RUN=1               ;;
    --full)        FULL_MODE=1              ;;
    --docker)      DO_DOCKER=1; SKIP_DOCKER=0 ;;
    --keep-logs)   KEEP_LOGS=1              ;;
    --report)      SHOW_REPORT=1            ;;
    --output=*)    OUTPUT_FILE="${arg#*=}"  ;;
    --output)      echo "Use --output=FILE"; exit 2 ;;
    -h|--help)     head -20 "$0"; exit 0   ;;
    *) echo "Unknown: $arg"; exit 2         ;;
  esac
done

if [[ -n "$OUTPUT_FILE" ]]; then exec > >(tee -a "$OUTPUT_FILE") 2>&1; fi

# ─── Helpers ────────────────────────────────────────────────────────────────
log()   { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[✗]${NC} $*"; }
info()  { echo -e "${CYAN}[i]${NC} $*"; }
title() { echo -e "\n${BOLD}${BLUE}━━━ $* ━━━${NC}"; }
hr()    { echo -e "${BLUE}──────────────────────────────────────────${NC}"; }

require_root() {
  if [[ $(id -u) -ne 0 ]]; then
    err "Run as root: sudo bash cleanup.sh"
    exit 1
  fi
}

confirm() {
  local prompt="$1"
  if [[ $FULL_MODE -eq 1 ]]; then return 0; fi
  read -r -p "$prompt [y/N] " resp
  [[ "$resp" =~ ^[yY] ]]
}

run() {
  local desc="$1"; shift
  echo -en "${CYAN}→${NC} $desc ... "
  if [[ $DRY_RUN -eq 1 ]]; then
    echo -e "${YELLOW}[DRY-RUN]${NC} $*"
    return 0
  fi
  if "$@" 2>/dev/null; then
    echo -e "${GREEN}ok${NC}"
  else
    echo -e "${YELLOW}skip (non-critical)${NC}"
  fi
}

measure_start() {
  START_USED=$(df / --output=used | tail -1)
  START_AVAIL=$(df / --output=avail | tail -1)
}

measure_end() {
  END_USED=$(df / --output=used | tail -1)
  END_AVAIL=$(df / --output=avail | tail -1)
  local freed_used=$(( START_USED - END_USED ))
  local freed_avail=$(( END_AVAIL - START_AVAIL ))
  echo
  hr
  echo -e "${BOLD}📊  DISK USAGE SUMMARY${NC}"
  hr
  echo -e "  Before: used=$(numfmt --to=iec $((START_USED*1024))), avail=$(numfmt --to=iec $((START_AVAIL*1024)))"
  echo -e "  After:  used=$(numfmt --to=iec $((END_USED*1024))), avail=$(numfmt --to=iec $((END_AVAIL*1024)))"
  if [[ $freed_avail -gt 0 ]]; then
    echo -e "  ${GREEN}Freed: ~$(numfmt --to=iec $((freed_avail*1024)))${NC}"
  elif [[ $freed_avail -eq 0 ]]; then
    echo -e "  Freed: ~0 (or very small)"
  else
    echo -e "  ${YELLOW}Something unexpected happened${NC}"
  fi
}

# ─── Main ───────────────────────────────────────────────────────────────────
main() {
  require_root

  echo -e "${BOLD}${BLUE}╔════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${BLUE}║       🧹  VPS CLEANUP TOOL  🧹       ║${NC}"
  echo -e "${BOLD}${BLUE}╚════════════════════════════════════════╝${NC}"
  echo -e "  Mode: ${BOLD}$([[ $DRY_RUN -eq 1 ]] && echo 'DRY-RUN' || echo 'LIVE')${NC}"
  echo -e "  Date: $(date -Is)"
  echo

  if [[ $SHOW_REPORT -eq 1 ]]; then
    title "DISK REPORT (no cleanup)"
    df -h / | awk '{print "  "$0}'
    echo
    title "TOP 10 LARGE DIRECTORIES"
    du -sh /* 2>/dev/null | sort -rh | head -10 | awk '{print "  "$0}'
    echo
    title "LARGE FILES (> ${LARGE_FILE_THRESHOLD})"
    find / -xdev -type f -size "+${LARGE_FILE_THRESHOLD}" -exec ls -lh {} \; 2>/dev/null \
      | sort -k5 -h | head -20
    echo
    exit 0
  fi

  measure_start

  if [[ $SHOW_REPORT -eq 0 && $DRY_RUN -eq 0 ]]; then
    confirm "Start cleanup?" || { info "Canceled."; exit 0; }
  fi

  # ───────────────────────────────────────────────────────────
  title "1/12  APT Cache & Unused Packages"
  # ───────────────────────────────────────────────────────────
  run "Clean apt cache"     apt-get clean -y
  run "Auto-clean apt"      apt-get autoclean -y
  run "Auto-remove orphans" apt-get autoremove -y
  FREED_ITEMS+=("APT cache")

  # ───────────────────────────────────────────────────────────
  title "2/12  Systemd Journal"
  # ───────────────────────────────────────────────────────────
  if [[ $KEEP_LOGS -eq 1 ]]; then
    info "Skipping journal cleanup (--keep-logs)"
  else
    run "Vacuum journal to ${JOURNAL_SIZE}" \
      journalctl --vacuum-size="${JOURNAL_SIZE}"
    FREED_ITEMS+=("Journal logs")
  fi

  # ───────────────────────────────────────────────────────────
  title "3/12  Rotated & Old Logs"
  # ───────────────────────────────────────────────────────────
  run "Remove .1-.9 rotated logs" \
    find /var/log -type f \( -name '*.1' -o -name '*.2' -o -name '*.3' \
      -o -name '*.4' -o -name '*.5' -o -name '*.6' -o -name '*.7' \
      -o -name '*.8' -o -name '*.9' \) -delete
  run "Remove .gz log archives older than 30d" \
    find /var/log -name '*.gz' -type f -mtime +30 -delete
  FREED_ITEMS+=("Rotated logs")

  # ───────────────────────────────────────────────────────────
  title "4/12  Temporary Files (older than 7 days)"
  # ───────────────────────────────────────────────────────────
  # Only clean /tmp files older than TMP_DAYS (safe range)
  run "Delete /tmp files older than 7 days" \
    find /tmp -type f -mtime "${TMP_DAYS}" -delete 2>/dev/null || true
  run "Delete /tmp empty dirs" \
    find /tmp -type d -empty -delete 2>/dev/null || true
  run "Clean /var/tmp files older than 7 days" \
    find /var/tmp -type f -mtime "${TMP_DAYS}" -delete 2>/dev/null || true
  FREED_ITEMS+=("Temp files")

  # ───────────────────────────────────────────────────────────
  title "5/12  Snap Cache & Old Snapshots"
  # ───────────────────────────────────────────────────────────
  # Safe: remove cache, leave installed snaps intact
  if command -v snap &>/dev/null; then
    local snap_cache_size=$(du -sb /var/lib/snapd/cache 2>/dev/null | cut -f1 || echo 0)
    run "Remove snap cache" \
      rm -rf /var/lib/snapd/cache/* 2>/dev/null || true
    run "Remove old snap seed snaps (seed, not installed)" \
      rm -f /var/lib/snapd/seed/snaps/*.snap 2>/dev/null || true
    FREED_ITEMS+=("Snap cache")
  else
    info "Snap not installed, skipping"
  fi

  # ───────────────────────────────────────────────────────────
  title "6/12  Python __pycache__ & .pyc"
  # ───────────────────────────────────────────────────────────
  run "Delete __pycache__ dirs" \
    find / -xdev -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
  run "Delete orphan .pyc files" \
    find / -xdev -type f -name '*.pyc' -not -path '*/node_modules/*' -delete 2>/dev/null || true
  FREED_ITEMS+=("Python cache")

  # ───────────────────────────────────────────────────────────
  title "7/12  Node.js .cache & orphan node_modules"
  # ───────────────────────────────────────────────────────────
  run "Clean npm cache" \
    rm -rf /root/.npm/_cacache 2>/dev/null || true
  run "Clean yarn cache" \
    rm -rf /root/.yarn/cache 2>/dev/null || true
  run "Clean pnpm store" \
    rm -rf /root/.pnpm-store 2>/dev/null || true
  run "Delete orphan node_modules/.cache" \
    find / -xdev -type d -path '*/node_modules/.cache' -exec rm -rf {} + 2>/dev/null || true
  FREED_ITEMS+=("Node cache")

  # ───────────────────────────────────────────────────────────
  title "8/12  Shell History & Trash"
  # ───────────────────────────────────────────────────────────
  run "Truncate root bash history (>500 lines)" \
    bash -c '[[ $(wc -l < ~/.bash_history 2>/dev/null) -gt 500 ]] && tail -500 ~/.bash_history > ~/.bash_history.tmp && mv ~/.bash_history.tmp ~/.bash_history || true' 2>/dev/null || true
  run "Clean .local/share/Trash" \
    rm -rf /root/.local/share/Trash/* 2>/dev/null || true
  FREED_ITEMS+=("Shell history")

  # ───────────────────────────────────────────────────────────
  title "9/12  Large Log Files (> 50 MB)"
  # ───────────────────────────────────────────────────────────
  # Rotate/compress large logs (warning only in dry-run)
  while IFS= read -r f; do
    if [[ -f "$f" ]]; then
      run "Compress $f" gzip -f "$f" 2>/dev/null || true
    fi
  done < <(find /var/log -type f -size +50M -not -name '*.gz' 2>/dev/null)
  FREED_ITEMS+=("Large logs compressed")

  # ───────────────────────────────────────────────────────────
  title "10/12  Orphan Packages (deborphan / cruft)"
  # ───────────────────────────────────────────────────────────
  if command -v deborphan &>/dev/null; then
    run "Remove orphaned packages" \
      deborphan | xargs -r apt-get -y remove 2>/dev/null || true
  else
    info "deborphan not installed. Install with: apt-get install deborphan"
  fi

  # ───────────────────────────────────────────────────────────
  title "11/12  Docker Cleanup"
  # ───────────────────────────────────────────────────────────
  if command -v docker &>/dev/null; then
    if [[ $DO_DOCKER -eq 1 ]]; then
      run "Docker: remove dangling images" docker image prune -f
      run "Docker: remove stopped containers" docker container prune -f
      run "Docker: remove unused volumes" docker volume prune -f
      run "Docker: remove build cache" docker builder prune -f
      warn "Run 'docker system prune -a --volumes -f' manually for full aggressive clean"
      FREED_ITEMS+=("Docker dangling")
    else
      info "Skipping Docker (use --docker to enable)"
    fi
  else
    info "Docker not installed, skipping"
  fi

  # ───────────────────────────────────────────────────────────
  title "12/12  Hermes Session Data (old)"
  # ───────────────────────────────────────────────────────────
  if [[ -d ~/.hermes/sessions ]]; then
    local sess_count=$(find ~/.hermes/sessions -name "*.jsonl" -mtime +30 2>/dev/null | wc -l)
    if [[ $sess_count -gt 0 ]]; then
      run "Delete Hermes sessions older than 30 days" \
        find ~/.hermes/sessions -name "*.jsonl" -mtime +30 -delete
      FREED_ITEMS+=("Old Hermes sessions")
    else
      info "No old Hermes sessions to clean"
    fi
  fi

  # ───────────────────────────────────────────────────────────
  # SUMMARY
  # ───────────────────────────────────────────────────────────
  measure_end

  if [[ ${#FREED_ITEMS[@]} -gt 0 ]]; then
    echo
    echo -e "${BOLD}🧹 Items cleaned:${NC}"
    for item in "${FREED_ITEMS[@]}"; do
      echo -e "  • $item"
    done
  fi

  # Check for restart-needed services
  if [[ -f /var/run/reboot-required.pkgs ]]; then
    warn "A reboot is required (kernel or lib updates pending)."
  fi

  echo
  echo -e "${GREEN}Done.${NC}"
}

main "$@"
