## Command Line

```bash
vt-check [OPTIONS] <file>
```

### Options

| Option | Description |
|--------|-------------|
| `--notify` | Show desktop notifications |
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
