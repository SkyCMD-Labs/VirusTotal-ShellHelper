# Audit Logging

The VirusTotal Shell Helper maintains a comprehensive audit log of all scans and file actions in JSON format.

## Overview

Every file scanned is tracked by its **SHA256 hash**. All actions performed on that file (across any location) are logged to a single JSON audit file. This provides a complete history of:

- Scans and results
- File tagging actions
- Quarantine operations
- Restore operations

## Audit Log Location

```
~/.local/share/virustotal-shell/audit/{file-hash}.json
```

Each file has one audit log named by its full SHA256 hash. The same malware in different locations shares the same audit log.

## JSON Structure

```json
{
  "file_hash": "275a021bbfb6489e54d471899f7db9d1663fc695ec2fe2a2c4538aabf651fd0f",
  "filename": "eicar.com.txt",
  "file_size": 68,
  "first_seen": 1772744728,
  "actions": [
    {
      "timestamp": 1772745022,
      "datetime": "2026-03-05T21:10:22+00:00",
      "action": "scan",
      "file_path": "/home/user/Desktop/eicar.com.txt",
      "result": "malicious",
      "malicious": "66",
      "suspicious": "0",
      "harmless": "0",
      "undetected": "3",
      "vt_url": "https://www.virustotal.com/gui/file/...",
      "scan_type": "existing"
    },
    {
      "timestamp": 1772745022,
      "datetime": "2026-03-05T21:10:22+00:00",
      "action": "tag_malicious",
      "file_path": "/home/user/Desktop/eicar.com.txt",
      "result": "success",
      "tag": "vt-malicious",
      "detections": "66",
      "original_perms": "644"
    },
    {
      "timestamp": 1772745023,
      "datetime": "2026-03-05T21:10:23+00:00",
      "action": "quarantine",
      "file_path": "/home/user/.local/share/virustotal-quarantine/275a021bbfb6489e-eicar.com.txt",
      "result": "success",
      "original_path": "/home/user/Desktop/eicar.com.txt",
      "original_perms": "444",
      "quarantine_path": "/home/user/.local/share/virustotal-quarantine/275a021bbfb6489e-eicar.com.txt",
      "original_filename": "eicar.com.txt"
    }
  ]
}
```

## Action Types

### scan
Records VirusTotal scan results.

**Fields:**
- `result`: `"clean"` or `"malicious"`
- `malicious`: Number of engines detecting as malicious
- `suspicious`: Number of engines detecting as suspicious
- `harmless`: Number of engines detecting as harmless
- `undetected`: Number of engines with no detection
- `vt_url`: Direct link to VirusTotal analysis
- `scan_type`: `"existing"` (hash found) or `"uploaded"` (new file uploaded)

### tag_clean
File tagged as clean after scan.

**Fields:**
- `tag`: `"vt-clean"`
- `result`: `"success"`

### tag_malicious
File tagged as malicious and permissions locked down.

**Fields:**
- `tag`: `"vt-malicious"`
- `detections`: Number of malicious detections
- `original_perms`: File permissions before lockdown (e.g., `"755"`)
- `result`: `"success"`

### quarantine
File moved to quarantine directory.

**Fields:**
- `original_path`: Full path where file was located
- `original_perms`: Permissions at time of quarantine
- `quarantine_path`: New location in quarantine (with hash prefix)
- `original_filename`: Original filename without hash prefix
- `result`: `"success"` or `"duplicate"` (if already quarantined)

### restore
File restored from quarantine.

**Fields:**
- `from_quarantine`: Original quarantine location
- `restored_perms`: Permissions restored to the file
- `result`: `"success"` or `"failed"`

## Benefits

### 1. Complete History
Track a file's journey across your system:
```bash
jq '.actions[] | "\(.datetime) - \(.action) - \(.file_path)"' \
  ~/.local/share/virustotal-shell/audit/{hash}.json
```

### 2. Same File, Different Locations
If you encounter the same malware in multiple locations, the audit log shows all occurrences:
```json
"actions": [
  {"file_path": "/home/user/Downloads/malware.exe", "action": "scan", ...},
  {"file_path": "/tmp/malware.exe", "action": "scan", ...}
]
```

### 3. Forensics
Investigate when a file was first seen and what actions were taken:
```bash
# Get first scan time
jq '.first_seen | todate' ~/.local/share/virustotal-shell/audit/{hash}.json

# Count total scans
jq '.actions | map(select(.action == "scan")) | length' \
  ~/.local/share/virustotal-shell/audit/{hash}.json

# Get all locations file appeared
jq '.actions[].file_path' ~/.local/share/virustotal-shell/audit/{hash}.json | sort -u
```

### 4. Detection Trends
See if detection counts change over time:
```bash
jq '.actions[] | select(.action == "scan") | {datetime, malicious}' \
  ~/.local/share/virustotal-shell/audit/{hash}.json
```

## Quarantine Filename Format

Quarantined files are named: `{hash-prefix}-{original-filename}`

Example: `275a021bbfb6489e-malware.exe`

This prevents:
- Filename collisions (different files with same name)
- Duplicate quarantine (same file quarantined multiple times)

The 16-character hash prefix links back to the audit log.

## Querying Audit Logs

### List all audited files
```bash
ls ~/.local/share/virustotal-shell/audit/
```

### View a specific audit log
```bash
jq . ~/.local/share/virustotal-shell/audit/{hash}.json
```

### Find all malicious files scanned
```bash
for log in ~/.local/share/virustotal-shell/audit/*.json; do
    if jq -e '.actions[] | select(.action == "scan" and .result == "malicious")' "$log" &>/dev/null; then
        echo "$(jq -r '.filename' "$log") - $(jq -r '.file_hash' "$log")"
    fi
done
```

### Find files with high detection rate
```bash
for log in ~/.local/share/virustotal-shell/audit/*.json; do
    detections=$(jq -r '.actions[] | select(.action == "scan") | .malicious' "$log" | head -1)
    if [[ "$detections" =~ ^[0-9]+$ ]] && [[ $detections -gt 50 ]]; then
        echo "$(jq -r '.filename' "$log"): $detections detections"
    fi
done
```

### Get restore candidates (quarantined files)
```bash
for log in ~/.local/share/virustotal-shell/audit/*.json; do
    if jq -e '.actions[] | select(.action == "quarantine")' "$log" &>/dev/null; then
        if ! jq -e '.actions[] | select(.action == "restore")' "$log" &>/dev/null; then
            quarantine_path=$(jq -r '.actions[] | select(.action == "quarantine") | .quarantine_path' "$log" | tail -1)
            if [[ -f "$quarantine_path" ]]; then
                echo "Still quarantined: $(jq -r '.filename' "$log")"
                echo "  Path: $quarantine_path"
                echo "  Original: $(jq -r '.actions[] | select(.action == "quarantine") | .original_path' "$log" | tail -1)"
            fi
        fi
    fi
done
```

## Privacy & Storage

- Audit logs contain file paths and hashes
- No file contents are stored
- Logs persist across reboots (not stored on tmpfs)
- Location: `~/.local/share/virustotal-shell/audit/`
- Each JSON file is typically < 1KB

### Cleanup

Remove old audit logs:
```bash
# Remove all audit logs
rm -rf ~/.local/share/virustotal-shell/audit/

# Remove specific file's audit log
rm ~/.local/share/virustotal-shell/audit/{hash}.json
```

## Technical Implementation

- **Key**: File SHA256 hash (same file = same audit log)
- **Format**: JSON with arrays for easy parsing
- **Append-only**: New actions are added to the `actions` array
- **Tool**: Uses `jq` for JSON manipulation when available
- **Fallback**: Creates new file if `jq` unavailable or parse fails

See `vt-actions.sh` function `log_audit()` for implementation details.

## Example: Complete Workflow Audit

```json
{
  "file_hash": "275a021bbfb6489e54d471899f7db9d1663fc695ec2fe2a2c4538aabf651fd0f",
  "filename": "suspicious.exe",
  "file_size": 12345,
  "first_seen": 1772744000,
  "actions": [
    {
      "datetime": "2026-03-05T20:00:00+00:00",
      "action": "scan",
      "result": "malicious",
      "malicious": "65",
      "vt_url": "https://...",
      "scan_type": "uploaded"
    },
    {
      "datetime": "2026-03-05T20:00:00+00:00",
      "action": "tag_malicious",
      "detections": "65",
      "original_perms": "755"
    },
    {
      "datetime": "2026-03-05T20:00:05+00:00",
      "action": "quarantine",
      "original_path": "/home/user/Downloads/suspicious.exe",
      "original_perms": "444"
    },
    {
      "datetime": "2026-03-06T10:30:00+00:00",
      "action": "restore",
      "from_quarantine": "/home/user/.local/share/virustotal-quarantine/275a021bbfb6489e-suspicious.exe"
    },
    {
      "datetime": "2026-03-06T10:31:00+00:00",
      "action": "scan",
      "result": "malicious",
      "malicious": "67",
      "scan_type": "existing"
    }
  ]
}
```

This shows:
1. Initial upload and detection (65 engines)
2. File tagged and locked down
3. Quarantined from Downloads
4. Later restored by user
5. Re-scanned (now 67 engines detect it)
