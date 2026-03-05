#!/usr/bin/env bash
#
# uninstall.sh - Uninstall VirusTotal Shell Helper
#

set -o pipefail

VERSION="1.0.0"
INSTALL_DIR="${HOME}/.local/bin"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Status indicators
OK="${GREEN}✓${NC}"
WARN="${YELLOW}⚠${NC}"
FAIL="${RED}✗${NC}"
INFO="${BLUE}ℹ${NC}"

print_header() {
    echo ""
    echo -e "${BOLD}$1${NC}"
    echo "─────────────────────────────────────────"
}

prompt_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local response
    
    if [[ "$default" == "y" ]]; then
        read -rp "$prompt [Y/n]: " response
        [[ -z "$response" || "$response" =~ ^[Yy] ]]
    else
        read -rp "$prompt [y/N]: " response
        [[ "$response" =~ ^[Yy] ]]
    fi
}

main() {
    echo ""
    echo -e "${BOLD}╔════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║  VirusTotal Shell Helper Uninstaller  ║${NC}"
    echo -e "${BOLD}╚════════════════════════════════════════╝${NC}"
    
    echo ""
    echo -e "${WARN} This will remove VirusTotal Shell Helper from your system"
    echo ""
    
    if ! prompt_yes_no "Continue with uninstallation?"; then
        echo "Uninstallation cancelled"
        exit 0
    fi
    
    # Remove scripts
    print_header "Removing Scripts"
    
    local scripts=("vt-check" "vt-actions.sh" "vt-manage")
    for script in "${scripts[@]}"; do
        if [[ -f "${INSTALL_DIR}/${script}" ]]; then
            rm -f "${INSTALL_DIR}/${script}"
            echo -e "${OK} Removed ${INSTALL_DIR}/${script}"
        fi
    done
    
    # Remove old vt-quarantine if exists
    if [[ -f "${INSTALL_DIR}/vt-quarantine" ]]; then
        rm -f "${INSTALL_DIR}/vt-quarantine"
        echo -e "${OK} Removed ${INSTALL_DIR}/vt-quarantine (old)"
    fi
    
    # Remove context menu integrations
    print_header "Removing Context Menu Integrations"
    
    # Nautilus
    if [[ -f "${HOME}/.local/share/nautilus/scripts/Scan with VirusTotal" ]]; then
        rm -f "${HOME}/.local/share/nautilus/scripts/Scan with VirusTotal"
        rm -f "${HOME}/.local/share/nautilus/scripts/Scan with VirusTotal (wait)"
        echo -e "${OK} Removed Nautilus scripts"
    fi
    
    # Nemo
    if [[ -f "${HOME}/.local/share/nemo/actions/vt-check.nemo_action" ]]; then
        rm -f "${HOME}/.local/share/nemo/actions/vt-check.nemo_action"
        rm -f "${HOME}/.local/share/nemo/actions/vt-check-nowait.nemo_action"
        echo -e "${OK} Removed Nemo actions"
    fi
    
    # Dolphin
    if [[ -f "${HOME}/.local/share/kio/servicemenus/vt-check.desktop" ]]; then
        rm -f "${HOME}/.local/share/kio/servicemenus/vt-check.desktop"
        rm -f "${HOME}/.local/share/kservices5/ServiceMenus/vt-check.desktop"
        echo -e "${OK} Removed Dolphin service menu"
    fi
    
    # Thunar
    if [[ -f "${HOME}/.config/Thunar/uca.xml" ]]; then
        if grep -q "vt-check" "${HOME}/.config/Thunar/uca.xml"; then
            echo -e "${WARN} Thunar custom actions found in uca.xml"
            echo "    Manual removal required - backup created at:"
            cp "${HOME}/.config/Thunar/uca.xml" "${HOME}/.config/Thunar/uca.xml.backup-uninstall"
            echo "    ${HOME}/.config/Thunar/uca.xml.backup-uninstall"
        fi
    fi
    
    # Caja
    if [[ -f "${HOME}/.config/caja/scripts/Scan with VirusTotal" ]]; then
        rm -f "${HOME}/.config/caja/scripts/Scan with VirusTotal"
        echo -e "${OK} Removed Caja scripts"
    fi
    
    # PCManFM
    if [[ -f "${HOME}/.local/share/applications/vt-check.desktop" ]]; then
        rm -f "${HOME}/.local/share/applications/vt-check.desktop"
        echo -e "${OK} Removed desktop entry"
    fi
    
    # Optional: Remove quarantine and audit data
    print_header "Data Cleanup"
    
    echo ""
    echo -e "${WARN} The following data directories exist:"
    echo ""
    
    local has_quarantine=false
    local has_audit=false
    
    if [[ -d "${HOME}/.local/share/virustotal-quarantine" ]]; then
        local quar_count=$(find "${HOME}/.local/share/virustotal-quarantine" -type f | wc -l)
        echo "  📦 Quarantine: ${HOME}/.local/share/virustotal-quarantine"
        echo "     Files: $quar_count"
        has_quarantine=true
    fi
    
    if [[ -d "${HOME}/.local/share/virustotal-shell/audit" ]]; then
        local audit_count=$(find "${HOME}/.local/share/virustotal-shell/audit" -name "*.json" | wc -l)
        echo "  📋 Audit logs: ${HOME}/.local/share/virustotal-shell/audit"
        echo "     Logs: $audit_count"
        has_audit=true
    fi
    
    echo ""
    
    if [[ "$has_quarantine" == "true" ]] || [[ "$has_audit" == "true" ]]; then
        if prompt_yes_no "Remove quarantine and audit data?"; then
            if [[ "$has_quarantine" == "true" ]]; then
                rm -rf "${HOME}/.local/share/virustotal-quarantine"
                echo -e "${OK} Removed quarantine directory"
            fi
            
            if [[ "$has_audit" == "true" ]]; then
                rm -rf "${HOME}/.local/share/virustotal-shell"
                echo -e "${OK} Removed audit logs"
            fi
        else
            echo -e "${INFO} Data directories preserved"
            echo "    Remove manually with:"
            [[ "$has_quarantine" == "true" ]] && echo "      rm -rf ~/.local/share/virustotal-quarantine"
            [[ "$has_audit" == "true" ]] && echo "      rm -rf ~/.local/share/virustotal-shell"
        fi
    else
        echo -e "${INFO} No data directories found"
    fi
    
    # Check for tmpfs mount
    print_header "System Mount Cleanup"
    
    if mount | grep -q "virustotal-quarantine"; then
        echo ""
        echo -e "${WARN} tmpfs mount detected for quarantine directory"
        echo ""
        if prompt_yes_no "Remove tmpfs mount and systemd unit? (requires sudo)"; then
            local mount_point="${HOME}/.local/share/virustotal-quarantine"
            local escaped_path=$(systemd-escape --path "$mount_point")
            local unit_file="/etc/systemd/system/${escaped_path}.mount"
            
            echo -e "${INFO} Unmounting..."
            sudo umount "$mount_point" 2>/dev/null || true
            
            echo -e "${INFO} Disabling systemd unit..."
            sudo systemctl disable "${escaped_path}.mount" 2>/dev/null || true
            
            echo -e "${INFO} Removing unit file..."
            sudo rm -f "$unit_file"
            
            echo -e "${INFO} Reloading systemd..."
            sudo systemctl daemon-reload
            
            echo -e "${OK} tmpfs mount removed"
        else
            echo -e "${INFO} tmpfs mount preserved"
            echo "    To remove manually, see docs/Isolation.md"
        fi
    else
        echo -e "${INFO} No tmpfs mount found"
    fi
    
    # Summary
    print_header "Uninstallation Complete"
    
    echo ""
    echo -e "${GREEN}✓ VirusTotal Shell Helper has been uninstalled${NC}"
    echo ""
    echo "Optionally, you may also want to:"
    echo "  • Remove vt CLI: rm ~/.local/bin/vt"
    echo "  • Remove vt config: rm ~/.vt.toml"
    echo ""
}

main "$@"
