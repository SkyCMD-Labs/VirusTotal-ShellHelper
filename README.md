# VirusTotal Shell Helper

[![Sync Wiki](https://github.com/SkyCMD-Labs/VirusTotal-ShellHelper/actions/workflows/sync-wiki.yml/badge.svg)](https://github.com/SkyCMD-Labs/VirusTotal-ShellHelper/actions/workflows/sync-wiki.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/bash-5.0+-blue.svg)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/platform-Linux-lightgrey.svg)](https://www.linux.org/)

A lightweight shell script to check file cleanliness via VirusTotal. No Python, no complex setup — just `vt` CLI, `jq`, and bash.

## Features

- **Hash-based lookup** — checks if file already exists in VirusTotal before uploading
- **Auto-upload** — uploads new files for analysis if not found
- **Desktop notifications** — supports notify-send, dunstify, kdialog, zenity
- **File manager integration** — right-click context menu for supported file managers
- **Auto-tagging** — tags files as clean/malicious (visible in KDE Dolphin)
- **Auto-lockdown** — removes execute/write permissions from malicious files
- **One-click quarantine** — isolate malicious files with noexec protection

## Quick Start

```bash
./install.sh
```

The installer will:
1. Check system dependencies
2. Download `vt` CLI if needed
3. Install `vt-check` to `~/.local/bin/`
4. Set up file manager context menu integration

After installation, configure your VirusTotal API key:

```bash
vt init
```

Get a free API key at: https://www.virustotal.com/gui/my-apikey

## Usage

```bash
vt-check [OPTIONS] <file>

Options:
  --no-wait    Don't wait for analysis if upload needed
  --notify     Show desktop notifications
  -h, --help   Show help
```

Or right-click any file → **Scan with VirusTotal**

## Supported Platforms

**Tested on:**
- CachyOS, KDE Plasma, Dolphin

**Should work on:**
- Most Linux distributions with supported file managers
- Notification backends: notify-send (libnotify), dunstify, kdialog, zenity
- File managers: Dolphin, Nautilus, Nemo, Thunar, Caja

Contributions and testing on other platforms welcome!

## Requirements

- `vt` — [VirusTotal CLI](https://github.com/VirusTotal/vt-cli)
- `jq` — JSON processor
- `sha256sum` — usually pre-installed

## Documentation

See [docs/](docs/) or the [**📖 Wiki**](https://github.com/SkyCMD-Labs/VirusTotal-ShellHelper/wiki) for detailed documentation:

- [Installation](https://github.com/SkyCMD-Labs/VirusTotal-ShellHelper/wiki/Installation) — setup guide
- [Usage](https://github.com/SkyCMD-Labs/VirusTotal-ShellHelper/wiki/Usage) — CLI options and examples
- [How It Works](https://github.com/SkyCMD-Labs/VirusTotal-ShellHelper/wiki/How-It-Works) — technical overview
- [File Managers](https://github.com/SkyCMD-Labs/VirusTotal-ShellHelper/wiki/File-Managers) — context menu setup
- [Quarantine & Tagging](https://github.com/SkyCMD-Labs/VirusTotal-ShellHelper/wiki/Quarantine-and-Tagging) — file tagging and quarantine features
- [Isolation](https://github.com/SkyCMD-Labs/VirusTotal-ShellHelper/wiki/Isolation) — noexec mount setup for enhanced security
- [Features](https://github.com/SkyCMD-Labs/VirusTotal-ShellHelper/wiki/Features) — quick reference guide
- [Troubleshooting](https://github.com/SkyCMD-Labs/VirusTotal-ShellHelper/wiki/Troubleshooting) — common issues

## Privacy & Security

> [!WARNING]
> Files uploaded to VirusTotal are shared with security researchers and antivirus companies. **Do not upload sensitive or confidential files.**

## Contributing

Contributions and testing on other platforms welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License — see [LICENSE](LICENSE) for details.

## Links

- [📖 Documentation Wiki](https://github.com/SkyCMD-Labs/VirusTotal-ShellHelper/wiki)
- [VirusTotal CLI](https://github.com/VirusTotal/vt-cli)
- [Get a Free API Key](https://www.virustotal.com/gui/my-apikey)

---

**Note:** This is an unofficial tool and is not affiliated with or endorsed by VirusTotal.
