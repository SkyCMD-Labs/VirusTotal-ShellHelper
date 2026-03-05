# VirusTotal File Actions & Quarantine

The VirusTotal Shell Helper now includes automatic file tagging, permission locking, and quarantine functionality for scan results.

## Features

### 🏷️ Automatic Tagging
Files are automatically tagged based on scan results:
- **`vt-clean`** - File passed VirusTotal scan
- **`vt-malicious`** - File detected as malicious
- **`vt-quarantined`** - File has been quarantined

Tags are visible in:
- Dolphin Information Panel (press `F11`)
- Dolphin sidebar under "Tags"
- Search with `tag:vt-malicious` in Dolphin

### 🔒 Automatic Lock-down
When a file is detected as malicious:
- Execute permissions removed (`chmod a-x`)
- Write permissions removed (`chmod a-w`)
- File becomes read-only to prevent accidental execution
- Original permissions stored in extended attributes

### 📦 Quarantine System
Malicious files can be quarantined with a single click from the notification.

**Quarantine Directory:** `~/.local/share/virustotal-quarantine`

Quarantined files:
- Moved to isolated directory with strict permissions (700)
- Set to read-only, no execute (chmod 400)
- Original path stored for potential restoration
- Can only be listed or deleted (not executed)

## Usage

### Scanning Files
```bash
# Scan with notifications enabled
vt-check --notify suspicious.exe

# If malicious, you'll get a notification with:
# - "View Results in Browser" button
# - "Quarantine File" button (auto-locks the file)
```

### Managing Quarantine

#### List quarantined files
```bash
vt-quarantine list
```

#### Open quarantine directory in file manager
```bash
vt-quarantine open
```

#### Get quarantine path
```bash
vt-quarantine path
```

#### Delete a quarantined file permanently
```bash
vt-quarantine delete ~/.local/share/virustotal-quarantine/malware.exe
```

#### Restore a file (⚠️ DANGEROUS - use extreme caution!)
```bash
vt-quarantine restore ~/.local/share/virustotal-quarantine/file.exe
```

## Viewing Tagged Files in Dolphin

1. **Information Panel** (F11)
   - Select any file
   - Tags appear in the Information panel on the right
   - Shows `vt-clean`, `vt-malicious`, or `vt-quarantined`

2. **Search by tag**
   ```
   tag:vt-malicious
   tag:vt-clean
   tag:vt-quarantined
   ```

3. **Tags sidebar**
   - View → Panels → Places
   - Tags section shows all tagged files

## Security Notes

⚠️ **IMPORTANT:**
- Quarantined files are still on your system
- They cannot be executed but can be read
- Delete quarantined files if you're certain they're malicious
- Only restore files if you're absolutely sure they're safe
- Scan restored files again before executing

### 🔒 Enhanced Isolation (Recommended)

By default, quarantined files have `chmod 400` (read-only, no execute). For **kernel-level isolation** that prevents execution even if permissions are changed:

```bash
sudo ./setup-system-mount.sh
```

This creates a system mount that:
- Auto-mounts on boot
- Uses tmpfs (cleared on reboot)
- Has noexec protection at kernel level
- Owned by your user (you can write/move files)

**See [Isolation](Isolation.md) for:**
- How it works
- Manual setup
- Management commands

## Technical Details

### Extended Attributes
Files store metadata using extended attributes (xattr):
- `user.vt.status` - Scan status (clean/malicious/quarantined)
- `user.vt.scan_time` - Unix timestamp of scan
- `user.vt.original_perms` - Original file permissions
- `user.vt.quarantine_time` - Quarantine timestamp
- `user.vt.original_path` - Original file location

View attributes:
```bash
getfattr -d -m user.vt file.exe
```

### Dependencies
- `balooctl6` - KDE Baloo file indexing (for tags)
- `setfattr` / `getfattr` - Extended attributes (optional, for metadata)

Check dependencies:
```bash
source vt-actions.sh
check_dependencies
```

## Installation

The new scripts are included in the project:
- `vt-actions.sh` - Core functionality (sourced by vt-check)
- `vt-quarantine` - Quarantine management CLI
- `vt-check` - Updated with auto-tagging and quarantine support

Install/update:
```bash
./install.sh
```

This will copy all scripts to `~/.local/bin/`

## Uninstallation

To remove all tags:
```bash
# Remove all vt-* tags from files (run in your home directory)
find ~ -type f -exec balooctl6 tag remove vt-clean {} \; 2>/dev/null
find ~ -type f -exec balooctl6 tag remove vt-malicious {} \; 2>/dev/null
find ~ -type f -exec balooctl6 tag remove vt-quarantined {} \; 2>/dev/null
```

To delete quarantine directory:
```bash
rm -rf ~/.local/share/virustotal-quarantine
```

## Example Workflow

1. Right-click suspicious file in Dolphin → "Scan with VirusTotal"
2. Notification appears with scan progress
3. If malicious:
   - File is auto-tagged as `vt-malicious`
   - Execute/write permissions removed
   - Notification shows "Quarantine File" button
4. Click "Quarantine File" to isolate it
5. File moved to quarantine with strict permissions
6. Later: `vt-quarantine list` to review
7. Delete permanently: `vt-quarantine delete <file>`
