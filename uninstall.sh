#!/bin/bash
# Removes everything install.sh set up. Deskflow and LocalSend themselves stay installed
# (remove them with: brew uninstall --cask deskflow localsend).

PREFIX="local.mac-pc-bridge"
for name in keyremap home-autostart; do
  launchctl bootout "gui/$(id -u)/$PREFIX.$name" 2>/dev/null
  rm -f "$HOME/Library/LaunchAgents/$PREFIX.$name.plist"
done
rm -rf "$HOME/Library/Application Support/mac-pc-bridge" "$HOME/Library/Logs/mac-pc-bridge"
echo "mac-pc-bridge removed. You can also remove 'keyremap' from System Settings -> Privacy & Security -> Accessibility."
