#!/bin/sh
# Install termanim for the current user: the KWin script, the `termanim` command, and the hotkey terminal.
set -e
here=$(cd "$(dirname "$0")" && pwd)

mkdir -p "$HOME/.local/share/kwin/scripts" "$HOME/.local/bin" "$HOME/.config/autostart" "$HOME/.local/share/applications"
rm -rf "$HOME/.local/share/kwin/scripts/termanim"
cp -r "$here/kwin-script" "$HOME/.local/share/kwin/scripts/termanim"
install -m 755 "$here/bin/termanim" "$HOME/.local/bin/termanim"
install -m 755 "$here/bin/termanim-settings" "$HOME/.local/bin/termanim-settings"
install -m 644 "$here/termanim-settings.desktop" "$HOME/.local/share/applications/termanim-settings.desktop"

# the hotkey terminal: a hidden Ghostty window that the script shows and animates
cat > "$HOME/.config/autostart/termanim-terminal.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=termanim hotkey terminal
Exec=systemd-run --user --unit=termanim-terminal -p Restart=always -p RestartSec=1 ghostty --class=dev.termanim.dropdown --gtk-single-instance=false --title="Drop-down Terminal"
EOF

kwriteconfig6 --file kwinrc --group Plugins --key termanimEnabled true
qdbus6 org.kde.KWin /KWin reconfigure
systemd-run --user --unit=termanim-terminal -p Restart=always -p RestartSec=1 ghostty --class=dev.termanim.dropdown --gtk-single-instance=false --title="Drop-down Terminal" 2>/dev/null || true

echo "Installed. Press F12 for the drop-down terminal; open \"Terminal Animations\" from your app menu (or run 'termanim-settings') to change the settings."
