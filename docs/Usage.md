## Command Line

```bash
vt-check [OPTIONS] <file>
```

### Options

| Option | Description |
|--------|-------------|
| `--notify` | Show desktop notifications |
| `--quarantine` | Automatically quarantine if malicious (no prompt) |
| `--no-wait` | Don't wait for analysis if file needs uploading |
| `-h, --help` | Show help message |

### Examples

**Basic scan (terminal output only):**
```bash
vt-check suspicious.exe
```

**With desktop notifications:**
```bash
vt-check --notify downloaded_file.bin
```

**Quick upload without waiting:**
```bash
vt-check --no-wait --notify largefile.iso
```

**Auto-quarantine if malicious:**
```bash
vt-check --notify --quarantine suspicious.exe
```

## Context Menu

Right-click any file in your file manager:

- **Scan with VirusTotal** — full scan, waits for results
- **Scan with VirusTotal (quick)** — uploads and returns immediately

> [!NOTE]
> Context menu names may vary slightly depending on your file manager, but functionality is the same.

## Output

### Terminal Output

```
Computing SHA256 hash...
Hash: 8739c76e681f900923b900c9df0ef75cf421d39cabb54650c4b9ad19b6a76d85
Checking VirusTotal database...
File already analyzed in VirusTotal

File:         /home/user/downloads/setup.exe
Type:         peexe
Last scanned: 2024-01-15 10:30
Status:       Clean
URL:          https://www.virustotal.com/gui/file/8739c76e...
```

### Status Values

| Status | Meaning |
|--------|---------|
| **Clean** | No engines detected anything malicious |
| **Malicious (N/total)** | N engines flagged as malicious or suspicious |

### Notifications

When `--notify` is enabled:

1. **Progress notifications** — shown during hash computation, lookup, upload
2. **Result notification** — persistent, shows final status
3. **Action button** — "View Results in Browser" opens VirusTotal page

Malicious files trigger **critical** urgency (red/interruptive on most DEs).

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Error (file not found, API error, etc.) |

## Use Cases

### Downloaded Files

Before running any downloaded executable:
```bash
vt-check --notify ~/Downloads/installer.exe
```

### Batch Scanning

Scan multiple files:
```bash
for f in ~/Downloads/*.exe; do
    vt-check "$f"
done
```

### Scripting

Check exit code and parse output:
```bash
if vt-check suspicious.bin 2>&1 | grep -q "Malicious"; then
    echo "WARNING: File flagged as malicious!"
fi
```

### Integrating with Other Tools

Use with `find` to scan recent downloads:
```bash
find ~/Downloads -mtime -1 -type f -exec vt-check --notify {} \;
```

## Quarantine and Audit Management

```bash
vt-manage <category> <command> [args]
```

### Quarantine Commands

| Command | Description |
|---------|-------------|
| `quarantine list` | List all quarantined files |
| `quarantine restore <hash-or-file>` | Restore a file from quarantine (DANGEROUS!) |
| `quarantine delete <hash-or-file>` | Permanently delete a quarantined file |
| `quarantine clear` | Remove all quarantined files (preserves audit logs) |
| `quarantine open` | Open quarantine directory in file manager |
| `quarantine path` | Print quarantine directory path |

### Audit Commands

| Command | Description |
|---------|-------------|
| `audit list` | List all audit logs with summary |
| `audit show <hash>` | Display full JSON audit log for a file |
| `audit clear` | Remove all audit logs (preserves quarantine files) |
| `audit path` | Print audit directory path |

### Quarantine Examples

**List quarantined files:**
```bash
vt-manage quarantine list
```

**Output:**
```
╔═════════════════════════════════════════════════════════════╗
║               QUARANTINED FILES                             ║
╠═════════════════════════════════════════════════════════════╣
║ ⚠ TMPFS Storage - Files cleared on reboot                  ║
╚═════════════════════════════════════════════════════════════╝

malware.exe
  Size:            12KB
  Hash:            8739c76e681f900923b900c9df0ef75cf421d39ca...
  Quarantined:     2026-03-05 14:30:15
  Original Path:   /home/user/Downloads/malware.exe
```

**Open quarantine folder:**
```bash
vt-manage quarantine open
```

**Delete a file permanently:**
```bash
# Using filename (searches audit logs)
vt-manage quarantine delete malware.exe

# Or using full SHA256 hash
vt-manage quarantine delete 8739c76e681f900923b900c9df0ef75cf421d39cabb54650c4b9ad19b6a76d85
```

**Restore a file (⚠️ use with caution!):**
```bash
# Using filename
vt-manage quarantine restore suspicious.exe

# Using hash
vt-manage quarantine restore 8739c76e...
# Will prompt for confirmation and restore to original location
```

**Clear all quarantine (preserves audit):**
```bash
vt-manage quarantine clear
```

**Get quarantine path:**
```bash
vt-manage quarantine path
```

### Audit Examples

**List all audit logs:**
```bash
vt-manage audit list
```

**Show full audit log for a file:**
```bash
vt-manage audit show 8739c76e681f900923b900c9df0ef75cf421d39cabb54650c4b9ad19b6a76d85
```

**Clear all audit logs (preserves quarantine):**
```bash
vt-manage audit clear
```

### Notes

- Quarantined files are stored using their full SHA256 hash (no extension)
- Use filename or full hash for restore/delete commands
- Filename lookup searches audit logs for matching files
- Restore retrieves original location and permissions from audit log
- All actions are logged to `~/.local/share/virustotal-shell/audit/`
- `quarantine clear` removes files but keeps audit history
- `audit clear` removes logs but keeps quarantined files

See [Quarantine-and-Tagging.md](Quarantine-and-Tagging.md) and [Audit-Logging.md](Audit-Logging.md) for more details.
