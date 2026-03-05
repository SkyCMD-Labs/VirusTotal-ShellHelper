# Troubleshooting

## Common Issues

### Permission Denied

**Symptom:** Error when running `vt-check` or context menu action fails silently.

**Solution:**
```bash
chmod +x ~/.local/bin/vt-check
```

For Dolphin service menus:
```bash
chmod +x ~/.local/share/kio/servicemenus/vt-check.desktop
```

### vt CLI Not Found

**Symptom:** `vt: command not found`

**Solutions:**

1. Run the installer which will download it:
   ```bash
   ./install.sh
   ```

2. Or manually install from [GitHub releases](https://github.com/VirusTotal/vt-cli/releases)

3. Ensure `~/.local/bin` is in your PATH:
   ```bash
   # bash/zsh
   export PATH="$HOME/.local/bin:$PATH"
   
   # fish
   fish_add_path $HOME/.local/bin
   ```

### API Key Not Configured

**Symptom:** `WrongCredentialsError` or `InvalidArgumentError`

**Solution:**
```bash
vt init
```

Get a free API key at: https://www.virustotal.com/gui/my-apikey

### Rate Limit Exceeded

**Symptom:** `QuotaExceededError`

**Cause:** Free VirusTotal API keys have rate limits (4 requests/minute, 500/day).

**Solution:** Wait a minute and try again, or upgrade to a premium API key.

### Context Menu Not Appearing

**Dolphin (KDE):**
- Restart Dolphin: `killall dolphin && dolphin`
- Check file exists and is executable:
  ```bash
  ls -la ~/.local/share/kio/servicemenus/vt-check.desktop
  ```

**Nautilus (GNOME):**
- Scripts appear under Right-click → Scripts submenu
- Restart Nautilus: `nautilus -q`

**Thunar (XFCE):**
- May require logout/login for changes to take effect
- Check `~/.config/Thunar/uca.xml` for syntax errors

**Nemo (Cinnamon):**
- Restart Nemo: `nemo -q`

### Notifications Not Working

**Check which backend is available:**
```bash
which notify-send dunstify kdialog zenity
```

**Install a notification daemon:**
```bash
# Arch/CachyOS
sudo pacman -S libnotify

# Ubuntu/Debian
sudo apt install libnotify-bin

# Fedora
sudo dnf install libnotify
```

### jq Not Found

**Install jq:**
```bash
# Arch/CachyOS
sudo pacman -S jq

# Ubuntu/Debian
sudo apt install jq

# Fedora
sudo dnf install jq
```

## Debugging

### Verbose Output

Run vt-check directly in terminal to see full output:
```bash
vt-check --notify /path/to/file
```

### Check vt CLI Directly

Test the vt CLI independently:
```bash
# Check a known file hash
vt file 44d88612fea8a8f36de82e1278abb02f --format json

# Test upload
vt scan file /path/to/file --format json
```

### Service Menu Debug (Dolphin)

Create a debug version:
```bash
cat > ~/.local/share/kio/servicemenus/vt-check-debug.desktop << 'EOF'
[Desktop Entry]
Type=Service
ServiceTypes=KonqPopupMenu/Plugin
MimeType=application/octet-stream;
Actions=debugScan;

[Desktop Action debugScan]
Name=Scan with VT (Debug)
Exec=konsole -e bash -c '~/.local/bin/vt-check --notify "%f"; read -p "Press enter..."'
EOF
chmod +x ~/.local/share/kio/servicemenus/vt-check-debug.desktop
```

This opens a terminal so you can see any errors.
