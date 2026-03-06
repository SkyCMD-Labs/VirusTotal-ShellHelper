#!/usr/bin/env bash
#
# Install script for VirusTotal Download Folder Watcher
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.local/bin"
SYSTEMD_DIR="${HOME}/.config/systemd/user"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║  VirusTotal Download Folder Watcher - Installer       ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Check dependencies
echo -e "${BLUE}Checking dependencies...${NC}"

if ! command -v vt-check &>/dev/null; then
    echo "Error: vt-check not found"
    echo "Please install VirusTotal Shell Helper first:"
    echo "  cd ../.. && ./install.sh"
    exit 1
fi

if ! command -v inotifywait &>/dev/null; then
    echo "Error: inotifywait not found"
    echo "Install inotify-tools:"
    echo "  sudo pacman -S inotify-tools    # Arch/CachyOS"
    echo "  sudo apt install inotify-tools  # Debian/Ubuntu"
    exit 1
fi

echo -e "${GREEN}✓${NC} All dependencies found"
echo ""

# Install script
echo -e "${BLUE}Installing vt-watch-downloads...${NC}"
mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/vt-watch-downloads" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/vt-watch-downloads"
echo -e "${GREEN}✓${NC} Installed to $INSTALL_DIR/vt-watch-downloads"
echo ""

# Install systemd service
echo -e "${BLUE}Installing systemd service...${NC}"
mkdir -p "$SYSTEMD_DIR"
cp "$SCRIPT_DIR/vt-watch-downloads.service" "$SYSTEMD_DIR/"
echo -e "${GREEN}✓${NC} Installed to $SYSTEMD_DIR/vt-watch-downloads.service"
echo ""

# Reload systemd
echo -e "${BLUE}Reloading systemd...${NC}"
systemctl --user daemon-reload
echo -e "${GREEN}✓${NC} Systemd reloaded"
echo ""

# Prompt to enable
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Installation complete!"
echo ""
echo "To enable and start the watcher:"
echo "  systemctl --user enable vt-watch-downloads"
echo "  systemctl --user start vt-watch-downloads"
echo ""
echo "To view logs in real-time:"
echo "  journalctl --user -u vt-watch-downloads -f"
echo ""
echo "To enable auto-quarantine, edit the service file:"
echo "  $SYSTEMD_DIR/vt-watch-downloads.service"
echo "  Add '--quarantine' flag to ExecStart line"
echo "  Then: systemctl --user daemon-reload && systemctl --user restart vt-watch-downloads"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
