#!/bin/sh
# Remove termanim and everything install.sh set up. Your other Ghostty settings are untouched.
"$HOME/.local/bin/termanim" reset >/dev/null 2>&1 || true   # clear saved settings
systemctl --user stop termanim-terminal 2>/dev/null || true
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript termanim 2>/dev/null || true
kwriteconfig6 --file kwinrc --group Plugins --key termanimEnabled --delete
rm -rf "$HOME/.cache/termanim" "$HOME/.local/share/kwin/scripts/termanim" "$HOME/.local/bin/termanim" "$HOME/.local/bin/termanim-settings" "$HOME/.local/share/applications/termanim-settings.desktop" "$HOME/.config/autostart/termanim-terminal.desktop"
qdbus6 org.kde.KWin /KWin reconfigure
echo "Removed."
