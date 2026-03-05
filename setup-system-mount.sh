#!/usr/bin/env bash
#
# Setup system-level quarantine mount that auto-starts on boot
# This requires sudo but only needs to be run once
#

set -e

USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")
USER_ID=$(id -u "$USER_NAME")
GROUP_ID=$(id -g "$USER_NAME")
QUARANTINE_DIR="${USER_HOME}/.local/share/virustotal-quarantine"

echo "Setting up system-level quarantine mount"
echo "========================================="
echo ""
echo "This will create a system mount unit that:"
echo "  - Auto-mounts on boot"
echo "  - Mounts with noexec protection"
echo "  - Owned by user: $USER_NAME (uid=$USER_ID)"
echo "  - Location: $QUARANTINE_DIR"
echo ""
echo "This requires sudo and only needs to be run once."
echo ""

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run with sudo:"
    echo "  sudo $0"
    exit 1
fi

read -p "Continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
fi

# Create quarantine directory
mkdir -p "$QUARANTINE_DIR"

# Generate proper systemd unit name
UNIT_NAME=$(systemd-escape -p --suffix=mount "$QUARANTINE_DIR")

echo ""
echo "Creating system mount unit: $UNIT_NAME"

# Create system mount unit
cat > "/etc/systemd/system/$UNIT_NAME" << EOF
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

# Reload systemd
systemctl daemon-reload

# Enable and start the mount
systemctl enable "$UNIT_NAME"
systemctl start "$UNIT_NAME"

# Verify
if mountpoint -q "$QUARANTINE_DIR"; then
    echo ""
    echo "✓ Success! Quarantine is now mounted and will auto-mount on boot"
    echo ""
    echo "Mount info:"
    findmnt "$QUARANTINE_DIR"
    echo ""
    
    # Test execution blocking
    TEST_FILE="${QUARANTINE_DIR}/test-exec.sh"
    echo '#!/bin/bash' > "$TEST_FILE"
    echo 'echo "Should not run!"' >> "$TEST_FILE"
    chmod +x "$TEST_FILE"
    
    if ! "$TEST_FILE" 2>&1 | grep -q "Permission denied"; then
        echo "⚠ Warning: Execution blocking may not be working"
    else
        echo "✓ Execution blocking verified (noexec is active)"
    fi
    
    rm -f "$TEST_FILE"
    
    echo ""
    echo "Management commands:"
    echo "  sudo systemctl status $UNIT_NAME    # Check status"
    echo "  sudo systemctl stop $UNIT_NAME      # Stop mount"
    echo "  sudo systemctl start $UNIT_NAME     # Start mount"
    echo "  sudo systemctl disable $UNIT_NAME   # Disable auto-mount"
else
    echo "✗ Mount failed"
    exit 1
fi
