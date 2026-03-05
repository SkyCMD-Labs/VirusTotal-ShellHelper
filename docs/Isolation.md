# Quarantine Isolation

By default, quarantined files have `chmod 400` (read-only, no execute), but for **true kernel-level isolation**, set up a noexec mount.

## 🔒 System Mount with noexec (Recommended)

This creates a system-level mount that auto-starts on boot and prevents all execution at the kernel level.

### Quick Setup

```bash
sudo ./setup-system-mount.sh
```

This script will:
1. Create a system-level mount unit
2. Mount tmpfs with `noexec,nosuid,nodev` flags
3. Set ownership to your user (you can write files)
4. Enable auto-mount on boot
5. Test that execution is blocked

**Features:**
- Quarantine stored in RAM (tmpfs)
- Cleared on reboot (extra secure)
- 500MB limit
- Auto-mounts on every boot
- Owned by your user
- Kernel-level noexec protection

### What It Does

Creates `/etc/systemd/system/home-<user>-.local-share-virustotal\x2dquarantine.mount` with:

```ini
[Unit]
Description=VirusTotal Quarantine (noexec tmpfs)
After=local-fs.target

[Mount]
What=tmpfs
Where=/home/<user>/.local/share/virustotal-quarantine
Type=tmpfs
Options=noexec,nosuid,nodev,mode=0700,size=500M,uid=<uid>,gid=<gid>

[Install]
WantedBy=multi-user.target
```

### Manual Setup (if needed)

If you want to set it up manually:

Run the automated script (recommended) or create the unit manually:

```bash
# Get your user ID
USER_ID=$(id -u)
GROUP_ID=$(id -g)
QUARANTINE_DIR="$HOME/.local/share/virustotal-quarantine"

# Generate systemd unit name
UNIT_NAME=$(systemd-escape -p --suffix=mount "$QUARANTINE_DIR")

# Create system mount unit
sudo tee "/etc/systemd/system/$UNIT_NAME" > /dev/null << EOF
[Unit]
Description=VirusTotal Quarantine (noexec tmpfs)
After=local-fs.target

[Mount]
What=tmpfs
Where=$QUARANTINE_DIR
Type=tmpfs
Options=noexec,nosuid,nodev,mode=0700,size=500M,uid=$USER_ID,gid=$GROUP_ID

[Install]
WantedBy=multi-user.target
EOF

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable "$UNIT_NAME"
sudo systemctl start "$UNIT_NAME"
```

### Verify It Works

```bash
# Check mount status
systemctl --user status vt-quarantine-noexec.mount

# Verify mount options
findmnt ~/.local/share/virustotal-quarantine

# Test execution is blocked
echo '#!/bin/bash' > ~/.local/share/virustotal-quarantine/test.sh
echo 'echo "Should not run!"' >> ~/.local/share/virustotal-quarantine/test.sh
chmod +x ~/.local/share/virustotal-quarantine/test.sh

# Try to execute (should fail with "Permission denied")
~/.local/share/virustotal-quarantine/test.sh
```

Expected output: `bash: ./test.sh: Permission denied`

### Management

```bash
# Start/mount
systemctl --user start vt-quarantine-noexec.mount

# Stop/unmount (to access backing storage or delete)
systemctl --user stop vt-quarantine-noexec.mount

# Status
systemctl --user status vt-quarantine-noexec.mount

# Disable auto-mount
systemctl --user disable vt-quarantine-noexec.mount
```

## 🛡️ Alternative: AppArmor (Advanced)

For even stricter control, use AppArmor to create system-wide policies.

**Note:** Requires AppArmor enabled on your system.

```bash
# Check if AppArmor is active
sudo systemctl status apparmor

# Run setup script (requires sudo)
./apparmor-quarantine
```

## 🔍 What Each Method Protects Against

| Method | Prevents Execution | Survives Reboot | Requires Root | Complexity |
|--------|-------------------|----------------|---------------|------------|
| `chmod 400` only | ⚠️ Basic | ✓ | ✗ | Low |
| noexec mount (tmpfs) | ✓✓ Kernel-level | ✗ Cleared | ✗ | Low |
| noexec mount (bind) | ✓✓ Kernel-level | ✓ | ✗ | Low |
| AppArmor | ✓✓✓ MAC policy | ✓ | ✓ | Medium |

## 💡 Recommendation

**For most users:** Use the **noexec bind mount** option
- Provides kernel-level protection
- Files persist for investigation
- No root access needed
- Works with existing vt-check setup
- Auto-mounts on login

Run: `./setup-quarantine-mount.sh` and choose option 2.

## ⚠️ Important Notes

1. **Existing quarantined files:** If you already have files in quarantine before setting up the mount, move them:
   ```bash
   # If using bind mount:
   mv ~/.local/share/virustotal-quarantine/* \
      ~/.local/share/virustotal-quarantine-storage/
   ```

2. **Script interpreters:** noexec prevents direct execution, but `bash ./script.sh` could still work. This is by design - you can inspect files without accidentally running them.

3. **File inspection:** You can still:
   - View files with `cat`, `less`, etc.
   - Open in hex editors
   - Extract with archive tools
   - Analyze with `strings`, `file`, etc.

4. **Compatibility:** Works with all existing vt-check, vt-quarantine commands. No changes needed.
