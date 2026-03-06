#!/usr/bin/env bash
#
# Uninstall script for VirusTotal Download Folder Watcher
#

set -e

INSTALL_DIR="${HOME}/.local/bin"
SYSTEMD_DIR="${HOME}/.config/systemd/user"
QUEUE_FILE="${HOME}/.local/share/virustotal-shell/scan-queue"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║  VirusTotal Download Folder Watcher - Uninstaller     ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Stop service if running
if systemctl --user is-active vt-watch-downloads &>/dev/null; then
    echo -e "${BLUE}Stopping service...${NC}"
    systemctl --user stop vt-watch-downloads
    echo -e "${GREEN}✓${NC} Service stopped"
    echo ""
fi

# Disable service if enabled
if systemctl --user is-enabled vt-watch-downloads &>/dev/null; then
    echo -e "${BLUE}Disabling service...${NC}"
    systemctl --user disable vt-watch-downloads
    echo -e "${GREEN}✓${NC} Service disabled"
    echo ""
fi

# Remove systemd service
if [[ -f "$SYSTEMD_DIR/vt-watch-downloads.service" ]]; then
    echo -e "${BLUE}Removing systemd service...${NC}"
    rm -f "$SYSTEMD_DIR/vt-watch-downloads.service"
    systemctl --user daemon-reload
    echo -e "${GREEN}✓${NC} Service file removed"
    echo ""
fi

# Remove script
if [[ -f "$INSTALL_DIR/vt-watch-downloads" ]]; then
    echo -e "${BLUE}Removing script...${NC}"
    rm -f "$INSTALL_DIR/vt-watch-downloads"
    echo -e "${GREEN}✓${NC} Script removed"
    echo ""
fi

# Ask about queue file
if [[ -f "$QUEUE_FILE" ]]; then
    echo -e "${YELLOW}Scan queue file found:${NC} $QUEUE_FILE"
    read -p "Remove scan queue? [y/N]: " response
    if [[ "$response" =~ ^[Yy] ]]; then
        rm -f "$QUEUE_FILE"
        echo -e "${GREEN}✓${NC} Queue file removed"
    else
        echo "Queue file preserved"
    fi
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}Uninstallation complete!${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
