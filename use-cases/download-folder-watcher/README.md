# Download Folder Watcher

Automatically scan new downloads with VirusTotal using inotify and systemd.

## What It Does

This use-case automatically watches your Downloads folder (or any directory you specify) and scans new files with VirusTotal as they appear. It uses inotify for efficient filesystem monitoring and systemd for reliable background operation.

**Features:**
- Watches for new files in real-time
- Skips browser partial downloads (`.part`, `.crdownload`, etc.)
- Respects VirusTotal API rate limits with intelligent queuing
- Only scans files under 32MB (free API limit)
- Desktop notifications for scan results
- Optional automatic quarantine of malicious files
- All logging via systemd journald (no log files to manage)

## Requirements

- VirusTotal Shell Helper (main project)
- `inotify-tools` package

Install inotify-tools:
```bash
sudo pacman -S inotify-tools    # Arch/CachyOS
sudo apt install inotify-tools  # Debian/Ubuntu
```

## Installation

```bash
./install.sh
```

This will:
1. Install `vt-watch-downloads` to `~/.local/bin/`
2. Install systemd user service
3. Reload systemd

## Usage

### Start the watcher:
```bash
systemctl --user enable vt-watch-downloads
systemctl --user start vt-watch-downloads
```

### View logs in real-time:
```bash
journalctl --user -u vt-watch-downloads -f
```

### Check status:
```bash
systemctl --user status vt-watch-downloads
```

### Stop the watcher:
```bash
systemctl --user stop vt-watch-downloads
```

## Configuration

Edit `~/.config/systemd/user/vt-watch-downloads.service`:

**Watch a different directory:**
```ini
ExecStart=%h/.local/bin/vt-watch-downloads --dir /path/to/watch
```

**Enable auto-quarantine:**
```ini
ExecStart=%h/.local/bin/vt-watch-downloads --quarantine
```

**Both:**
```ini
ExecStart=%h/.local/bin/vt-watch-downloads --dir /path/to/watch --quarantine
```

After editing, reload:
```bash
systemctl --user daemon-reload
systemctl --user restart vt-watch-downloads
```

## How It Works

1. **inotify** watches for `close_write` and `moved_to` events in your Downloads folder
2. New files are checked against ignore patterns (browser temp files, hidden files)
3. File size is verified (must be under 32MB)
4. Files are added to a scan queue
5. Queue processor scans files with 15-second delay (respects API rate limits)
6. Results trigger desktop notifications
7. Malicious files are optionally quarantined

## Uninstallation

```bash
./uninstall.sh
```

This will:
1. Stop and disable the service
2. Remove the systemd service file
3. Remove the script
4. Optionally remove the scan queue

## Troubleshooting

**Service won't start:**
```bash
journalctl --user -u vt-watch-downloads -n 50
```

**Check if inotify is working:**
```bash
vt-watch-downloads --help
```

**Manually test the script:**
```bash
vt-watch-downloads
# Download a file and watch the output
```

## Notes

- The watcher respects VirusTotal's free API limits (4 requests/minute)
- Browser partial downloads are automatically skipped
- Files larger than 32MB are skipped (VirusTotal free API limit)
- All output goes to systemd journal - use `journalctl` to view logs
- The scan queue persists across restarts in `~/.local/share/virustotal-shell/scan-queue`
