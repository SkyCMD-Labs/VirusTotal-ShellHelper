#!/usr/bin/env bash
#
# vt-check installer
# Performs system checks, installs dependencies, and sets up file manager context menus
#

set -o pipefail

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.local/bin"
VT_CLI_REPO="VirusTotal/vt-cli"

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

# Detected environment
ARCH=""
NOTIFY_BACKEND=""
DESKTOP_ENV=""
FILE_MANAGER=""

#------------------------------------------------------------------------------
# Utility functions
#------------------------------------------------------------------------------

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

#------------------------------------------------------------------------------
# Detection functions
#------------------------------------------------------------------------------

detect_architecture() {
    local arch
    arch=$(uname -m)
    
    case "$arch" in
        x86_64|amd64)
            ARCH="Linux64"
            ;;
        i386|i686)
            ARCH="Linux32"
            ;;
        aarch64|arm64)
            ARCH="LinuxARM64"
            ;;
        armv7l|armhf)
            ARCH="LinuxARM"
            ;;
        *)
            ARCH=""
            ;;
    esac
}

detect_notification_backend() {
    if command -v notify-send &>/dev/null; then
        NOTIFY_BACKEND="notify-send (libnotify)"
    elif command -v dunstify &>/dev/null; then
        NOTIFY_BACKEND="dunstify (Dunst)"
    elif command -v kdialog &>/dev/null; then
        NOTIFY_BACKEND="kdialog (KDE)"
    elif command -v zenity &>/dev/null; then
        NOTIFY_BACKEND="zenity (GTK)"
    else
        NOTIFY_BACKEND=""
    fi
}

detect_desktop_environment() {
    # Check XDG_CURRENT_DESKTOP first
    if [[ -n "$XDG_CURRENT_DESKTOP" ]]; then
        case "$XDG_CURRENT_DESKTOP" in
            *GNOME*|*gnome*|*Unity*)
                DESKTOP_ENV="gnome"
                ;;
            *KDE*|*kde*|*Plasma*)
                DESKTOP_ENV="kde"
                ;;
            *XFCE*|*xfce*|*Xfce*)
                DESKTOP_ENV="xfce"
                ;;
            *Cinnamon*|*cinnamon*)
                DESKTOP_ENV="cinnamon"
                ;;
            *MATE*|*mate*)
                DESKTOP_ENV="mate"
                ;;
            *LXQt*|*lxqt*)
                DESKTOP_ENV="lxqt"
                ;;
            *LXDE*|*lxde*)
                DESKTOP_ENV="lxde"
                ;;
            *Pantheon*|*pantheon*)
                DESKTOP_ENV="pantheon"
                ;;
            *)
                DESKTOP_ENV="unknown"
                ;;
        esac
    elif [[ -n "$DESKTOP_SESSION" ]]; then
        case "$DESKTOP_SESSION" in
            *gnome*|*ubuntu*)
                DESKTOP_ENV="gnome"
                ;;
            *plasma*|*kde*)
                DESKTOP_ENV="kde"
                ;;
            *xfce*)
                DESKTOP_ENV="xfce"
                ;;
            *)
                DESKTOP_ENV="unknown"
                ;;
        esac
    else
        DESKTOP_ENV="unknown"
    fi
}

detect_file_manager() {
    # Detect based on desktop environment and installed file managers
    case "$DESKTOP_ENV" in
        gnome|pantheon)
            if command -v nautilus &>/dev/null; then
                FILE_MANAGER="nautilus"
            elif command -v nemo &>/dev/null; then
                FILE_MANAGER="nemo"
            fi
            ;;
        kde)
            if command -v dolphin &>/dev/null; then
                FILE_MANAGER="dolphin"
            fi
            ;;
        xfce)
            if command -v thunar &>/dev/null; then
                FILE_MANAGER="thunar"
            fi
            ;;
        cinnamon)
            if command -v nemo &>/dev/null; then
                FILE_MANAGER="nemo"
            fi
            ;;
        mate)
            if command -v caja &>/dev/null; then
                FILE_MANAGER="caja"
            fi
            ;;
        lxqt)
            if command -v pcmanfm-qt &>/dev/null; then
                FILE_MANAGER="pcmanfm-qt"
            fi
            ;;
        lxde)
            if command -v pcmanfm &>/dev/null; then
                FILE_MANAGER="pcmanfm"
            fi
            ;;
    esac
    
    # Fallback detection if not found by DE
    if [[ -z "$FILE_MANAGER" ]]; then
        for fm in nautilus nemo dolphin thunar caja pcmanfm pcmanfm-qt; do
            if command -v "$fm" &>/dev/null; then
                FILE_MANAGER="$fm"
                break
            fi
        done
    fi
}

#------------------------------------------------------------------------------
# Installation functions
#------------------------------------------------------------------------------

install_vt_cli() {
    print_header "Installing VirusTotal CLI"
    
    if [[ -z "$ARCH" ]]; then
        echo -e "${FAIL} Unsupported architecture: $(uname -m)"
        echo "    Please install vt-cli manually from:"
        echo "    https://github.com/VirusTotal/vt-cli/releases"
        return 1
    fi
    
    # Check for required tools
    local downloader=""
    if command -v curl &>/dev/null; then
        downloader="curl"
    elif command -v wget &>/dev/null; then
        downloader="wget"
    else
        echo -e "${FAIL} Neither curl nor wget found. Please install one of them."
        return 1
    fi
    
    if ! command -v unzip &>/dev/null; then
        echo -e "${FAIL} unzip not found. Please install it first."
        return 1
    fi
    
    echo -e "${INFO} Fetching latest release info..."
    
    # Get latest release URL
    local api_url="https://api.github.com/repos/${VT_CLI_REPO}/releases/latest"
    local release_json
    
    if [[ "$downloader" == "curl" ]]; then
        release_json=$(curl -sL "$api_url")
    else
        release_json=$(wget -qO- "$api_url")
    fi
    
    if [[ -z "$release_json" ]]; then
        echo -e "${FAIL} Failed to fetch release information"
        return 1
    fi
    
    # Parse download URL for our architecture
    local download_url
    download_url=$(echo "$release_json" | grep -o "https://github.com/${VT_CLI_REPO}/releases/download/[^\"]*${ARCH}.zip" | head -1)
    
    if [[ -z "$download_url" ]]; then
        echo -e "${FAIL} Could not find download for architecture: ${ARCH}"
        return 1
    fi
    
    local version
    version=$(echo "$release_json" | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4)
    
    echo -e "${INFO} Downloading vt-cli ${version} for ${ARCH}..."
    
    # Create temp directory
    local tmp_dir
    tmp_dir=$(mktemp -d)
    local zip_file="${tmp_dir}/vt-cli.zip"
    
    # Download
    if [[ "$downloader" == "curl" ]]; then
        curl -sL "$download_url" -o "$zip_file"
    else
        wget -q "$download_url" -O "$zip_file"
    fi
    
    if [[ ! -f "$zip_file" ]]; then
        echo -e "${FAIL} Download failed"
        rm -rf "$tmp_dir"
        return 1
    fi
    
    echo -e "${INFO} Extracting..."
    unzip -q "$zip_file" -d "$tmp_dir"
    
    # Find the vt binary
    local vt_binary
    vt_binary=$(find "$tmp_dir" -name "vt" -type f | head -1)
    
    if [[ -z "$vt_binary" ]]; then
        echo -e "${FAIL} Could not find vt binary in archive"
        rm -rf "$tmp_dir"
        return 1
    fi
    
    # Install to ~/.local/bin
    mkdir -p "$INSTALL_DIR"
    chmod +x "$vt_binary"
    mv "$vt_binary" "${INSTALL_DIR}/vt"
    
    rm -rf "$tmp_dir"
    
    echo -e "${OK} vt-cli ${version} installed to ${INSTALL_DIR}/vt"
    
    # Check if ~/.local/bin is in PATH
    if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
        echo ""
        echo -e "${WARN} ${INSTALL_DIR} is not in your PATH"
        echo "    Add this to your shell config:"
        echo ""
        echo "    For bash (~/.bashrc):"
        echo "      export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo ""
        echo "    For fish (~/.config/fish/config.fish):"
        echo "      fish_add_path \$HOME/.local/bin"
        echo ""
        echo "    For zsh (~/.zshrc):"
        echo "      export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
    
    return 0
}

install_vt_check() {
    print_header "Installing vt-check and related scripts"
    
    mkdir -p "$INSTALL_DIR"
    
    # Install vt-check
    local source_script="${SCRIPT_DIR}/vt-check"
    
    if [[ ! -f "$source_script" ]]; then
        echo -e "${FAIL} vt-check script not found at ${source_script}"
        return 1
    fi
    
    cp "$source_script" "${INSTALL_DIR}/vt-check"
    chmod +x "${INSTALL_DIR}/vt-check"
    echo -e "${OK} vt-check installed to ${INSTALL_DIR}/vt-check"
    
    # Install vt-actions.sh
    local actions_script="${SCRIPT_DIR}/vt-actions.sh"
    if [[ -f "$actions_script" ]]; then
        cp "$actions_script" "${INSTALL_DIR}/vt-actions.sh"
        chmod +x "${INSTALL_DIR}/vt-actions.sh"
        echo -e "${OK} vt-actions.sh installed to ${INSTALL_DIR}/vt-actions.sh"
    else
        echo -e "${WARN} vt-actions.sh not found, skipping..."
    fi
    
    # Install vt-quarantine
    local quarantine_script="${SCRIPT_DIR}/vt-quarantine"
    if [[ -f "$quarantine_script" ]]; then
        cp "$quarantine_script" "${INSTALL_DIR}/vt-quarantine"
        chmod +x "${INSTALL_DIR}/vt-quarantine"
        echo -e "${OK} vt-quarantine installed to ${INSTALL_DIR}/vt-quarantine"
    else
        echo -e "${WARN} vt-quarantine not found, skipping..."
    fi
    
    return 0
}

#------------------------------------------------------------------------------
# Context menu installation functions
#------------------------------------------------------------------------------

install_nautilus_action() {
    # Nautilus uses Python extensions or nautilus-actions
    # Modern Nautilus (GNOME Files) uses ~/.local/share/nautilus/scripts/
    local scripts_dir="${HOME}/.local/share/nautilus/scripts"
    mkdir -p "$scripts_dir"
    
    cat > "${scripts_dir}/Scan with VirusTotal" << 'EOF'
#!/usr/bin/env bash
# Nautilus script for VirusTotal scanning

for file in "$NAUTILUS_SCRIPT_SELECTED_FILE_PATHS"; do
    if [[ -n "$file" ]] && [[ -f "$file" ]]; then
        ~/.local/bin/vt-check --notify "$file" &
    fi
done
EOF
    
    # Handle both environment variable styles
    cat > "${scripts_dir}/Scan with VirusTotal (wait)" << 'EOF'
#!/usr/bin/env bash
# Nautilus script for VirusTotal scanning (waits for results)

IFS=$'\n'
for file in $NAUTILUS_SCRIPT_SELECTED_FILE_PATHS; do
    if [[ -n "$file" ]] && [[ -f "$file" ]]; then
        ~/.local/bin/vt-check --notify "$file"
    fi
done
EOF
    
    chmod +x "${scripts_dir}/Scan with VirusTotal"
    chmod +x "${scripts_dir}/Scan with VirusTotal (wait)"
    
    echo -e "${OK} Nautilus scripts installed"
    echo "    Access via: Right-click → Scripts → Scan with VirusTotal"
}

install_nemo_action() {
    # Nemo uses .nemo_action files
    local actions_dir="${HOME}/.local/share/nemo/actions"
    mkdir -p "$actions_dir"
    
    cat > "${actions_dir}/vt-check.nemo_action" << EOF
[Nemo Action]
Name=Scan with VirusTotal
Comment=Check file against VirusTotal database
Exec=${INSTALL_DIR}/vt-check --notify %F
Icon-Name=security-medium
Selection=any
Extensions=any;
Quote=double
EOF
    
    cat > "${actions_dir}/vt-check-nowait.nemo_action" << EOF
[Nemo Action]
Name=Scan with VirusTotal (quick)
Comment=Upload to VirusTotal without waiting for results
Exec=${INSTALL_DIR}/vt-check --notify --no-wait %F
Icon-Name=security-medium
Selection=any
Extensions=any;
Quote=double
EOF
    
    chmod +x "${actions_dir}/vt-check.nemo_action"
    chmod +x "${actions_dir}/vt-check-nowait.nemo_action"
    
    echo -e "${OK} Nemo actions installed"
    echo "    Access via: Right-click → Scan with VirusTotal"
}

install_dolphin_action() {
    # Dolphin uses .desktop files in ~/.local/share/kio/servicemenus/ (KDE 5/6)
    # or ~/.local/share/kservices5/ServiceMenus/ (older KDE 5)
    local services_dir="${HOME}/.local/share/kio/servicemenus"
    mkdir -p "$services_dir"
    
    cat > "${services_dir}/vt-check.desktop" << EOF
[Desktop Entry]
Type=Service
ServiceTypes=KonqPopupMenu/Plugin
MimeType=application/octet-stream;
Actions=scanVT;scanVTNoWait;

[Desktop Action scanVT]
Name=Scan with VirusTotal
Icon=security-medium
Exec=${INSTALL_DIR}/vt-check --notify %f

[Desktop Action scanVTNoWait]
Name=Scan with VirusTotal (quick)
Icon=security-medium
Exec=${INSTALL_DIR}/vt-check --notify --no-wait %f
EOF
    
    chmod +x "${services_dir}/vt-check.desktop"
    
    # Also install to legacy location
    local legacy_dir="${HOME}/.local/share/kservices5/ServiceMenus"
    mkdir -p "$legacy_dir"
    cp "${services_dir}/vt-check.desktop" "${legacy_dir}/"
    chmod +x "${legacy_dir}/vt-check.desktop"
    
    echo -e "${OK} Dolphin service menu installed"
    echo "    Access via: Right-click → Actions → Scan with VirusTotal"
}

install_thunar_action() {
    # Thunar uses custom actions stored in ~/.config/Thunar/uca.xml
    local thunar_dir="${HOME}/.config/Thunar"
    local uca_file="${thunar_dir}/uca.xml"
    
    mkdir -p "$thunar_dir"
    
    # Check if uca.xml exists
    if [[ -f "$uca_file" ]]; then
        # Check if our action already exists
        if grep -q "vt-check" "$uca_file"; then
            echo -e "${INFO} Thunar action already exists, skipping..."
            return 0
        fi
        
        # Backup existing file
        cp "$uca_file" "${uca_file}.backup"
        
        # Insert our action before </actions>
        local action_xml='<action>
	<icon>security-medium</icon>
	<name>Scan with VirusTotal</name>
	<submenu></submenu>
	<unique-id>vt-check-scan</unique-id>
	<command>'"${INSTALL_DIR}"'/vt-check --notify %f</command>
	<description>Check file against VirusTotal database</description>
	<range>*</range>
	<patterns>*</patterns>
	<other-files/>
	<directories/>
</action>
<action>
	<icon>security-medium</icon>
	<name>Scan with VirusTotal (quick)</name>
	<submenu></submenu>
	<unique-id>vt-check-scan-nowait</unique-id>
	<command>'"${INSTALL_DIR}"'/vt-check --notify --no-wait %f</command>
	<description>Upload to VirusTotal without waiting</description>
	<range>*</range>
	<patterns>*</patterns>
	<other-files/>
	<directories/>
</action>'
        
        # Use sed to insert before </actions>
        sed -i "s|</actions>|${action_xml}\n</actions>|" "$uca_file"
    else
        # Create new uca.xml
        cat > "$uca_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<actions>
<action>
	<icon>security-medium</icon>
	<name>Scan with VirusTotal</name>
	<submenu></submenu>
	<unique-id>vt-check-scan</unique-id>
	<command>${INSTALL_DIR}/vt-check --notify %f</command>
	<description>Check file against VirusTotal database</description>
	<range>*</range>
	<patterns>*</patterns>
	<other-files/>
	<directories/>
</action>
<action>
	<icon>security-medium</icon>
	<name>Scan with VirusTotal (quick)</name>
	<submenu></submenu>
	<unique-id>vt-check-scan-nowait</unique-id>
	<command>${INSTALL_DIR}/vt-check --notify --no-wait %f</command>
	<description>Upload to VirusTotal without waiting</description>
	<range>*</range>
	<patterns>*</patterns>
	<other-files/>
	<directories/>
</action>
</actions>
EOF
    fi
    
    echo -e "${OK} Thunar custom actions installed"
    echo "    Access via: Right-click → Scan with VirusTotal"
    echo "    Note: You may need to restart Thunar or log out/in"
}

install_caja_action() {
    # Caja (MATE) uses caja-actions or scripts similar to nautilus
    local scripts_dir="${HOME}/.config/caja/scripts"
    mkdir -p "$scripts_dir"
    
    cat > "${scripts_dir}/Scan with VirusTotal" << 'EOF'
#!/usr/bin/env bash
# Caja script for VirusTotal scanning

for file in "$@"; do
    if [[ -n "$file" ]] && [[ -f "$file" ]]; then
        ~/.local/bin/vt-check --notify "$file" &
    fi
done
EOF
    
    chmod +x "${scripts_dir}/Scan with VirusTotal"
    
    echo -e "${OK} Caja scripts installed"
    echo "    Access via: Right-click → Scripts → Scan with VirusTotal"
}

install_pcmanfm_action() {
    # PCManFM and PCManFM-Qt use custom actions in config
    echo -e "${WARN} PCManFM does not support custom context menu actions"
    echo "    You can create a .desktop file to use with 'Open With'"
    
    # Create a .desktop file that can be used with "Open With"
    local apps_dir="${HOME}/.local/share/applications"
    mkdir -p "$apps_dir"
    
    cat > "${apps_dir}/vt-check.desktop" << EOF
[Desktop Entry]
Name=Scan with VirusTotal
Comment=Check file against VirusTotal database
Exec=${INSTALL_DIR}/vt-check --notify %f
Icon=security-medium
Terminal=false
Type=Application
Categories=Security;Utility;
MimeType=application/octet-stream;
EOF
    
    echo -e "${OK} Desktop entry created"
    echo "    Use 'Open With' → 'Scan with VirusTotal'"
}

install_context_menu() {
    print_header "Installing Context Menu Integration"
    
    if [[ -z "$FILE_MANAGER" ]]; then
        echo -e "${WARN} No supported file manager detected"
        echo "    Skipping context menu installation"
        return 1
    fi
    
    echo -e "${INFO} Detected file manager: ${FILE_MANAGER}"
    echo ""
    
    case "$FILE_MANAGER" in
        nautilus)
            install_nautilus_action
            ;;
        nemo)
            install_nemo_action
            ;;
        dolphin)
            install_dolphin_action
            ;;
        thunar)
            install_thunar_action
            ;;
        caja)
            install_caja_action
            ;;
        pcmanfm|pcmanfm-qt)
            install_pcmanfm_action
            ;;
        *)
            echo -e "${WARN} No context menu integration available for ${FILE_MANAGER}"
            return 1
            ;;
    esac
    
    return 0
}

#------------------------------------------------------------------------------
# System check
#------------------------------------------------------------------------------

run_system_check() {
    print_header "System Check"
    
    # Architecture
    detect_architecture
    echo -e "${INFO} Architecture: $(uname -m) → ${ARCH:-unsupported}"
    
    # OS
    if [[ -f /etc/os-release ]]; then
        local distro
        distro=$(grep "^PRETTY_NAME" /etc/os-release | cut -d'"' -f2)
        echo -e "${INFO} Distribution: ${distro}"
    fi
    
    # Desktop environment
    detect_desktop_environment
    echo -e "${INFO} Desktop: ${XDG_CURRENT_DESKTOP:-unknown} (${DESKTOP_ENV})"
    
    # File manager
    detect_file_manager
    if [[ -n "$FILE_MANAGER" ]]; then
        echo -e "${INFO} File manager: ${FILE_MANAGER}"
    else
        echo -e "${WARN} File manager: not detected"
    fi
    
    echo ""
    
    # Check required tools
    print_header "Dependency Check"
    
    # vt CLI
    if command -v vt &>/dev/null; then
        local vt_version
        vt_version=$(vt version 2>/dev/null | head -1)
        echo -e "${OK} vt CLI: ${vt_version}"
        VT_INSTALLED=true
    else
        echo -e "${FAIL} vt CLI: not found"
        VT_INSTALLED=false
    fi
    
    # jq
    if command -v jq &>/dev/null; then
        local jq_version
        jq_version=$(jq --version 2>/dev/null)
        echo -e "${OK} jq: ${jq_version}"
        JQ_INSTALLED=true
    else
        echo -e "${FAIL} jq: not found (required)"
        JQ_INSTALLED=false
    fi
    
    # sha256sum
    if command -v sha256sum &>/dev/null; then
        echo -e "${OK} sha256sum: available"
    else
        echo -e "${FAIL} sha256sum: not found (required)"
    fi
    
    # Notification backend
    detect_notification_backend
    if [[ -n "$NOTIFY_BACKEND" ]]; then
        echo -e "${OK} Notifications: ${NOTIFY_BACKEND}"
    else
        echo -e "${WARN} Notifications: no backend found"
        echo "    Install one of: libnotify (notify-send), dunst (dunstify), kdialog, or zenity"
    fi
    
    # Optional: xdg-open for browser
    if command -v xdg-open &>/dev/null; then
        echo -e "${OK} xdg-open: available (for opening browser)"
    else
        echo -e "${WARN} xdg-open: not found (browser links won't work)"
    fi
    
    # Baloo (for KDE tagging)
    if command -v balooctl6 &>/dev/null; then
        echo -e "${OK} balooctl6: available (for file tagging)"
    else
        echo -e "${WARN} balooctl6: not found (file tagging won't work on KDE)"
        echo "    Install with: sudo pacman -S baloo (Arch/CachyOS)"
    fi
    
    # Extended attributes
    if command -v setfattr &>/dev/null && command -v getfattr &>/dev/null; then
        echo -e "${OK} xattr tools: available (for file metadata)"
    else
        echo -e "${WARN} xattr tools: not found (optional, for storing metadata)"
        echo "    Install with: sudo pacman -S attr (Arch/CachyOS)"
    fi
    
    # Download tools
    local has_downloader=false
    if command -v curl &>/dev/null; then
        echo -e "${OK} curl: available"
        has_downloader=true
    fi
    if command -v wget &>/dev/null; then
        echo -e "${OK} wget: available"
        has_downloader=true
    fi
    if [[ "$has_downloader" == "false" ]]; then
        echo -e "${WARN} Neither curl nor wget found (needed to download vt-cli)"
    fi
    
    if command -v unzip &>/dev/null; then
        echo -e "${OK} unzip: available"
    else
        echo -e "${WARN} unzip: not found (needed to install vt-cli)"
    fi
}

#------------------------------------------------------------------------------
# Main installation flow
#------------------------------------------------------------------------------

main() {
    echo ""
    echo -e "${BOLD}╔════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║     vt-check Installer v${VERSION}          ║${NC}"
    echo -e "${BOLD}╚════════════════════════════════════════╝${NC}"
    
    # Run system check
    run_system_check
    
    echo ""
    
    # Install vt-cli if needed
    if [[ "$VT_INSTALLED" != "true" ]]; then
        echo ""
        if prompt_yes_no "vt CLI not found. Download and install it?"; then
            install_vt_cli || echo -e "${WARN} vt-cli installation failed"
        else
            echo -e "${WARN} Skipping vt-cli installation"
            echo "    vt-check requires vt CLI to function"
        fi
    fi
    
    # Check for jq
    if [[ "$JQ_INSTALLED" != "true" ]]; then
        echo ""
        echo -e "${FAIL} jq is required but not installed"
        echo "    Install it using your package manager:"
        echo "      Arch/CachyOS: sudo pacman -S jq"
        echo "      Ubuntu/Debian: sudo apt install jq"
        echo "      Fedora: sudo dnf install jq"
        echo ""
    fi
    
    # Install vt-check script
    echo ""
    if prompt_yes_no "Install vt-check script to ${INSTALL_DIR}?" "y"; then
        install_vt_check
    fi
    
    # Install context menu
    if [[ -n "$FILE_MANAGER" ]]; then
        echo ""
        if prompt_yes_no "Install ${FILE_MANAGER} context menu integration?" "y"; then
            install_context_menu
        fi
    fi
    
    # Final instructions
    print_header "Next Steps"
    
    # Check if vt is configured
    local vt_config="${HOME}/.vt.toml"
    if [[ ! -f "$vt_config" ]]; then
        echo -e "${WARN} VirusTotal CLI is not configured yet"
        echo ""
        echo "    Run the following command to set up your API key:"
        echo ""
        echo -e "    ${BOLD}vt init${NC}"
        echo ""
        echo "    You'll need a VirusTotal API key. Get one free at:"
        echo "    https://www.virustotal.com/gui/my-apikey"
        echo ""
    else
        echo -e "${OK} VirusTotal CLI is configured"
        echo ""
    fi
    
    echo "    Test vt-check by running:"
    echo ""
    echo -e "    ${BOLD}vt-check --notify /path/to/some/file${NC}"
    echo ""
    
    if [[ -n "$FILE_MANAGER" ]]; then
        echo "    Or right-click a file in ${FILE_MANAGER} and select:"
        echo "    'Scan with VirusTotal'"
        echo ""
    fi
    
    echo "    Additional commands:"
    echo -e "    ${BOLD}vt-quarantine list${NC}      - View quarantined files"
    echo -e "    ${BOLD}vt-quarantine open${NC}      - Open quarantine folder"
    echo ""
    echo "    See QUARANTINE.md for details on tagging and quarantine features"
    echo ""
    
    echo -e "${GREEN}Installation complete!${NC}"
}

main "$@"
