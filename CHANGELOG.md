# Changelog

All notable changes to this project are documented here.

## [2.0.0] - 2026-06-12

### Added
- **Docker cleanup** (optional, use `--docker` to enable)
  - Prune dangling images, stopped containers, unused volumes, build cache
- **Snap cleanup** — remove snap cache & old seed snapshots
- **Python `__pycache__` & `.pyc`** — scan entire filesystem
- **Node.js cache** — clean npm/yarn/pnpm caches + `node_modules/.cache`
- **Large log compress** — auto-gzip logs >50 MB
- **Shell history** — trim `~/.bash_history` (keeps last 500 lines)
- **Orphan packages** — `deborphan` detection (if installed)
- **Old Hermes sessions** — prune `.jsonl` files older than 30 days
- **`--full` mode** — unattended auto-clean (no confirm prompts)
- **`--report` mode** — view large files & disk usage without cleaning
- **`--output=FILE`** — save full report to log file
- **Before/after summary** — shows freed disk space in human-readable format

### Changed
- **Improved `/tmp` safety** — only deletes files older than 7 days (was `rm -rf /tmp/*`)
- **Rotated logs** — now also cleans `.gz` archives older than 30 days
- **Journal cleanup** — configurable size/age (default: 50 MB / 7 days)
- **Color output & progress indicators** — easier to read
- **Error handling** — non-critical failures don't abort the script
- **Code structure** — modular functions, better argument parsing

### Fixed
- `apt-get autoremove` no longer runs before `apt-get clean`
- Journal vacuum failure no longer stops the entire script

## [1.0.0] - 2025-09-23

### Added
- Initial release: APT cache clean, autoremove, journal vacuum, /tmp clean
- `--dry-run` and `--keep-logs` flags
- Basic before/after disk usage report
