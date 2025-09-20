# cleanup.sh

A Safe VPS cleanup for Ubuntu/Debian to clean up unused packages, logs, and temporary files on a Linux server.

## Usage

```bash
sudo bash cleanup.sh
```

## Options

```
--keep-logs
````
Keep systemd journal logs (skip log vacuum).

```
--dry-run
```
Show commands without running them.


## What the script does

Run apt-get clean, autoclean, and autoremove.

Vacuum systemd logs to keep only the last 7 days.

Clean /tmp/*.

Display a disk usage summary before and after cleanup.
