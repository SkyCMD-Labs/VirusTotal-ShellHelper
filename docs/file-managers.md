# File Manager Integration

The installer automatically sets up context menus for supported file managers. This document covers manual setup and customization.

## Supported File Managers

| File Manager | Desktop | Support Level |
|--------------|---------|---------------|
| Dolphin | KDE Plasma | ✅ Full (service menus) |
| Nautilus | GNOME | ✅ Scripts submenu |
| Nemo | Cinnamon | ✅ Full (actions) |
| Thunar | XFCE | ✅ Full (custom actions) |
| Caja | MATE | ✅ Scripts submenu |
| PCManFM | LXDE/LXQt | ⚠️ Open With only |

## Dolphin (KDE)

### Location
```
~/.local/share/kio/servicemenus/vt-check.desktop
```

Legacy location (KDE 5):
```
~/.local/share/kservices5/ServiceMenus/vt-check.desktop
```

### Manual Setup

```bash
mkdir -p ~/.local/share/kio/servicemenus

cat > ~/.local/share/kio/servicemenus/vt-check.desktop << 'EOF'
[Desktop Entry]
Type=Service
ServiceTypes=KonqPopupMenu/Plugin
MimeType=application/octet-stream;
Actions=scanVT;scanVTNoWait;

[Desktop Action scanVT]
Name=Scan with VirusTotal
Icon=security-medium
Exec=~/.local/bin/vt-check --notify %f

[Desktop Action scanVTNoWait]
Name=Scan with VirusTotal (quick)
Icon=security-medium
Exec=~/.local/bin/vt-check --notify --no-wait %f
EOF

chmod +x ~/.local/share/kio/servicemenus/vt-check.desktop
```

### Applying Changes

```bash
# Restart Dolphin
killall dolphin && dolphin &
```

## Nautilus (GNOME Files)

### Location
```
~/.local/share/nautilus/scripts/
```

### Manual Setup

```bash
mkdir -p ~/.local/share/nautilus/scripts

cat > ~/.local/share/nautilus/scripts/Scan\ with\ VirusTotal << 'EOF'
#!/usr/bin/env bash
IFS=$'\n'
for file in $NAUTILUS_SCRIPT_SELECTED_FILE_PATHS; do
    if [[ -n "$file" ]] && [[ -f "$file" ]]; then
        ~/.local/bin/vt-check --notify "$file"
    fi
done
EOF

chmod +x ~/.local/share/nautilus/scripts/Scan\ with\ VirusTotal
```

### Accessing

Right-click → **Scripts** → **Scan with VirusTotal**

### Applying Changes

```bash
nautilus -q
```

## Nemo (Cinnamon)

### Location
```
~/.local/share/nemo/actions/
```

### Manual Setup

```bash
mkdir -p ~/.local/share/nemo/actions

cat > ~/.local/share/nemo/actions/vt-check.nemo_action << 'EOF'
[Nemo Action]
Name=Scan with VirusTotal
Comment=Check file against VirusTotal database
Exec=~/.local/bin/vt-check --notify %F
Icon-Name=security-medium
Selection=any
Extensions=any;
Quote=double
EOF

chmod +x ~/.local/share/nemo/actions/vt-check.nemo_action
```

### Applying Changes

```bash
nemo -q
```

## Thunar (XFCE)

### Location
```
~/.config/Thunar/uca.xml
```

### Manual Setup

Edit `~/.config/Thunar/uca.xml` and add inside `<actions>`:

```xml
<action>
    <icon>security-medium</icon>
    <name>Scan with VirusTotal</name>
    <submenu></submenu>
    <unique-id>vt-check-scan</unique-id>
    <command>~/.local/bin/vt-check --notify %f</command>
    <description>Check file against VirusTotal database</description>
    <range>*</range>
    <patterns>*</patterns>
    <other-files/>
    <directories/>
</action>
```

Or create from scratch:

```bash
mkdir -p ~/.config/Thunar

cat > ~/.config/Thunar/uca.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<actions>
<action>
    <icon>security-medium</icon>
    <name>Scan with VirusTotal</name>
    <submenu></submenu>
    <unique-id>vt-check-scan</unique-id>
    <command>~/.local/bin/vt-check --notify %f</command>
    <description>Check file against VirusTotal</description>
    <range>*</range>
    <patterns>*</patterns>
    <other-files/>
    <directories/>
</action>
</actions>
EOF
```

### Applying Changes

Logout and login, or:
```bash
thunar -q
```

## Caja (MATE)

### Location
```
~/.config/caja/scripts/
```

### Manual Setup

```bash
mkdir -p ~/.config/caja/scripts

cat > ~/.config/caja/scripts/Scan\ with\ VirusTotal << 'EOF'
#!/usr/bin/env bash
for file in "$@"; do
    if [[ -n "$file" ]] && [[ -f "$file" ]]; then
        ~/.local/bin/vt-check --notify "$file" &
    fi
done
EOF

chmod +x ~/.config/caja/scripts/Scan\ with\ VirusTotal
```

### Accessing

Right-click → **Scripts** → **Scan with VirusTotal**

## PCManFM / PCManFM-Qt

PCManFM doesn't support custom context menu actions. As a workaround, create a .desktop file for "Open With":

```bash
cat > ~/.local/share/applications/vt-check.desktop << 'EOF'
[Desktop Entry]
Name=Scan with VirusTotal
Comment=Check file against VirusTotal database
Exec=~/.local/bin/vt-check --notify %f
Icon=security-medium
Terminal=false
Type=Application
Categories=Security;Utility;
MimeType=application/octet-stream;
EOF
```

Then use: Right-click → **Open With** → **Scan with VirusTotal**

## Customization

### Different Icon

Change `Icon=security-medium` to any icon name from your theme:
- `security-high` — green shield
- `security-medium` — yellow shield
- `security-low` — red shield
- `dialog-warning`
- `emblem-important`

### Submenu Organization

For Dolphin, add multiple actions under a submenu:

```ini
[Desktop Entry]
Type=Service
ServiceTypes=KonqPopupMenu/Plugin
MimeType=application/octet-stream;
X-KDE-Submenu=VirusTotal
Actions=scanVT;scanVTNoWait;
```

### Restrict to Certain File Types

For Nemo, change `Extensions=any;` to specific types:
```ini
Extensions=exe;msi;bin;sh;
```

For Dolphin, change `MimeType`:
```ini
MimeType=application/x-executable;application/x-msdos-program;
```
