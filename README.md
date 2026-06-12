# cleanup.sh 🧹

Advanced VPS Cleanup for Debian/Ubuntu — safely free up disk space, remove unused packages, logs, caches, and temporary files.

## Quick Start

```bash
sudo bash cleanup.sh                  # interactive (asks per step)
sudo bash cleanup.sh --full           # unattended (skip docker)
sudo bash cleanup.sh --full --docker  # full + docker prune
```

## Features

| Category | What it cleans |
|----------|---------------|
| **APT** | `clean`, `autoclean`, `autoremove` |
| **Systemd Journal** | Vacuum to configurable size (default 50 MB) or age (7 days) |
| **Rotated Logs** | `.1` – `.9` archives + `.gz` older than 30 days |
| **Temporary Files** | `/tmp` & `/var/tmp` files older than 7 days (safe) |
| **Snap** | Cache directory + old seed snapshots |
| **Python** | All `__pycache__` directories + orphan `*.pyc` files |
| **Node.js** | `npm` / `yarn` / `pnpm` caches + `node_modules/.cache` |
| **Large Logs** | Auto-compress log files > 50 MB |
| **Shell History** | Trim `~/.bash_history` to last 500 lines |
| **Orphan Packages** | `deborphan` detection (if installed) |
| **Docker** (opt-in) | Dangling images, stopped containers, unused volumes, build cache |
| **Hermes Sessions** | Prune session files older than 30 days |
| **Before/After Report** | Shows exact freed space in human-readable format |

## Options

```
--full           Unattended mode (no confirmation prompts)
--docker         Include Docker cleanup (without --full, Docker is skipped)
--dry-run        Show what would be done without executing
--keep-logs      Skip systemd journal vacuum
--report         Only scan & display large files, no cleanup
--output=FILE    Save full output to a log file
```

### Examples

```bash
# Preview only
sudo bash cleanup.sh --dry-run

# Quick report of disk usage & large files
sudo bash cleanup.sh --report

# Full unattended + Docker + save log
sudo bash cleanup.sh --full --docker --output=cleanup-$(date +%F).log
```

## Requirements

- Debian / Ubuntu
- Root access (`sudo`)
- Optional: `deborphan` for orphan package detection

## License

MIT © 2026 yujiwh
