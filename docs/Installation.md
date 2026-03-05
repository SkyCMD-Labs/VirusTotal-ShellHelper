## Quick Install

```bash
git clone https://github.com/SkyCMD-Labs/VirusTotal-ShellHelper.git
cd VirusTotal-ShellHelper
./install.sh
```

The installer handles everything interactively.

> [!TIP]
> The installer will automatically detect your system and download the vt CLI if needed.

## Manual Installation

1. **System Check** — detects your architecture, distro, desktop environment, and file manager
2. **Dependency Check** — verifies required tools are installed
3. **vt CLI Installation** — downloads from GitHub releases if not found
4. **vt-check Installation** — copies script to `~/.local/bin/`
5. **Context Menu Setup** — installs file manager integration

## Manual Installation

### 1. Install Dependencies

**Required:**
```bash
# Arch/CachyOS
sudo pacman -S jq

# Ubuntu/Debian
sudo apt install jq

# Fedora
sudo dnf install jq
```

**Optional (for notifications):**
```bash
# Most distros have one of these
sudo pacman -S libnotify    # provides notify-send
sudo pacman -S dunst        # provides dunstify
```

### 2. Install VirusTotal CLI

Download from [GitHub releases](https://github.com/VirusTotal/vt-cli/releases):

```bash
# Example for Linux x86_64
wget https://github.com/VirusTotal/vt-cli/releases/latest/download/Linux64.zip
unzip Linux64.zip
chmod +x vt
mv vt ~/.local/bin/
```

### 3. Configure API Key

```bash
vt init
```

> [!IMPORTANT]
> You must run `vt init` to configure your API key before using vt-check.

Get a free API key at: https://www.virustotal.com/gui/my-apikey

### 4. Install vt-check

```bash
cp vt-check ~/.local/bin/
chmod +x ~/.local/bin/vt-check
```

### 5. Add to PATH (if needed)

If `~/.local/bin` isn't in your PATH:

```bash
# bash (~/.bashrc)
export PATH="$HOME/.local/bin:$PATH"

# zsh (~/.zshrc)
export PATH="$HOME/.local/bin:$PATH"

# fish (~/.config/fish/config.fish)
fish_add_path $HOME/.local/bin
```

### 6. Install Context Menu (Optional)

See [File Manager Integration](file-managers.md) for manual setup.

## Verifying Installation

```bash
# Check vt-check is available
which vt-check

# Check vt CLI is configured
vt version

# Test on any file
vt-check --notify /usr/bin/ls
```

## Uninstallation

```bash
# Remove scripts
rm ~/.local/bin/vt-check

# Remove context menus (varies by file manager)
rm ~/.local/share/kio/servicemenus/vt-check.desktop          # Dolphin
rm ~/.local/share/nemo/actions/vt-check*.nemo_action         # Nemo
rm ~/.local/share/nautilus/scripts/Scan\ with\ VirusTotal*   # Nautilus
# For Thunar, manually edit ~/.config/Thunar/uca.xml
```

The `vt` CLI and its config (`~/.vt.toml`) can be kept for other uses.
