# VirusTotal File Actions & Quarantine

The VirusTotal Shell Helper now includes automatic file tagging, permission locking, and quarantine functionality for scan results.

## Features

### 🏷️ Automatic Tagging
Files are automatically tagged based on scan results:
- **`vt-clean`** - File passed VirusTotal scan
- **`vt-malicious`** - File detected as malicious
- **`vt-quarantined`** - File has been moved to quarantine

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
- Stored using full SHA256 hash (no extension, prevents collisions)
- Moved to isolated directory with strict permissions (700)
- Set to read-only, no execute (chmod 400)
- Complete action history tracked in JSON audit log
- Can be restored to original location with original permissions

### 📋 Audit Logging
All scans and file actions are logged to:
```
~/.local/share/virustotal-shell/audit/{file-hash}.json
```

Each file (tracked by SHA256 hash) has a complete audit trail:
- Scan results and detection counts
- Tag and lockdown actions
- Quarantine and restore operations
- VirusTotal URLs for reference

**See [Audit-Logging.md](Audit-Logging.md) for full documentation.**

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

Use the `vt-manage` command with two-level structure: `vt-manage <category> <command>`

#### List quarantined files
```bash
vt-manage quarantine list
```

#### Open quarantine directory in file manager
```bash
vt-manage quarantine open
```

#### Get quarantine path
```bash
vt-manage quarantine path
```

#### Delete a quarantined file permanently
```bash
# Using original filename (searches audit logs)
vt-manage quarantine delete malware.exe

# Or using full SHA256 hash
vt-manage quarantine delete 8739c76e681f900923b900c9df0ef75cf421d39cabb54650c4b9ad19b6a76d85
```

#### Clear all quarantine files (preserves audit logs)
```bash
vt-manage quarantine clear
```

#### Restore a file (⚠️ DANGEROUS - use extreme caution!)
```bash
# Using original filename
vt-manage quarantine restore file.exe

# Or using full hash
vt-manage quarantine restore 8739c76e...
```

Restore reads metadata from the audit log to:
- Restore to original location
- Restore original permissions
- Log the restore action

### Managing Audit Logs

#### List all audit logs
```bash
vt-manage audit list
```

Shows all files with audit history:
- Filename
- SHA256 hash
- First seen timestamp
- Number of logged actions

#### View full audit log for a file
```bash
vt-manage audit show <hash>
```

Displays complete JSON audit log including:
- All scan results
- Tag and lockdown actions
- Quarantine and restore operations

#### Clear all audit logs (preserves quarantine files)
```bash
vt-manage audit clear
```

## Viewing Tagged Files in Dolphin

1. **Information Panel** (F11)
   - Select any file
   - Tags appear in the Information panel on the right
   - Shows `vt-clean`, `vt-malicious`, or `vt-quarantined`

2. **Search by tag**
   - Press Ctrl+F in Dolphin
   - Type: `tag:vt-malicious`
   - Or: `tag:vt-clean`, `tag:vt-quarantined`

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

### Metadata Storage

**Audit Logs (Primary):**
All scan results and file actions are logged in JSON format:
```
~/.local/share/virustotal-shell/audit/{SHA256}.json
```

This provides:
- Complete action history per file (by hash)
- Scan results with detection counts
- Quarantine metadata for restore
- Persistent across reboots

**Extended Attributes (Secondary):**
Files also store metadata using xattr (when supported):
- `user.xdg.tags` - Visual tags (vt-clean, vt-malicious, vt-quarantined)
- `user.vt.status` - Scan status
- `user.vt.scan_time` - Unix timestamp
- `user.vt.original_perms` - Original permissions (for non-quarantined files)

View attributes:
```bash
getfattr -d -m user file.exe
```

**Note:** Quarantine metadata (original_path, original_perms) is stored in audit logs, not xattr, because tmpfs (quarantine storage) doesn't support user extended attributes.

### Dependencies
- `balooctl6` - KDE Baloo file indexing (for tags)
- `setfattr` / `getfattr` - Extended attributes (optional, for metadata)

Check dependencies:
```bash
source vt-actions.sh
check_dependencies
```

## Installation

The scripts are included in the project:
- `vt-check` - Main scanning tool with auto-tagging and quarantine support
- `vt-actions.sh` - Core functionality library (sourced by vt-check)
- `vt-manage` - Quarantine and audit management CLI

Install/update:
```bash
./install.sh
```

This will install all scripts to `~/.local/bin/` and optionally set up tmpfs quarantine mount.

## Uninstallation

### Automated Uninstall (Recommended)
```bash
./uninstall.sh
```

The uninstaller will:
1. Remove all installed scripts
2. Remove file manager integrations
3. Optionally remove quarantine and audit data
4. Optionally remove tmpfs mount (if configured)

### Manual Tag Removal

To remove all vt-* tags from files:
```bash
# Remove all vt-* tags (run in your home directory)
find ~ -type f -exec balooctl6 tag remove vt-clean {} \; 2>/dev/null
find ~ -type f -exec balooctl6 tag remove vt-malicious {} \; 2>/dev/null
find ~ -type f -exec balooctl6 tag remove vt-quarantined {} \; 2>/dev/null
```

### Manual Data Removal

```bash
# Remove quarantine directory
rm -rf ~/.local/share/virustotal-quarantine

# Remove audit logs
rm -rf ~/.local/share/virustotal-shell
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
6. Later: `vt-manage quarantine list` to review
7. Delete permanently: `vt-manage quarantine delete <file-or-hash>`
