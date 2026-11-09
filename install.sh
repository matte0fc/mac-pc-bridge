#!/bin/bash
# mac-pc-bridge installer (macOS side)
#   1. installs Deskflow and LocalSend (Homebrew)
#   2. builds and starts keyremap (Windows shortcuts on the Mac)
#   3. sets up home-autostart for the network you are on right now
# Safe to run again: it replaces its own files and agents.

set -euo pipefail
cd "$(dirname "$0")"

BASE="$HOME/Library/Application Support/mac-pc-bridge"
LOGS="$HOME/Library/Logs/mac-pc-bridge"
AGENTS="$HOME/Library/LaunchAgents"
PREFIX="local.mac-pc-bridge"
UID_NUM=$(id -u)

say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
fail() { printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }

[ "$(uname)" = Darwin ] || fail "This installer is for macOS. See the README for the Windows side."
command -v brew >/dev/null || fail "Homebrew is missing. Install it from https://brew.sh and run this again."
command -v swiftc >/dev/null || fail "Swift is missing. Run: xcode-select --install"

mkdir -p "$BASE" "$LOGS" "$AGENTS"

# ---------- 1. Apps ----------
say "1/3  Apps"
if [ -d /Applications/Deskflow.app ]; then
  echo "Deskflow already installed"
else
  brew tap deskflow/tap
  brew trust deskflow/tap 2>/dev/null || true   # newer Homebrew asks you to trust third-party taps
  brew install --cask deskflow/tap/deskflow
fi
if [ -d /Applications/LocalSend.app ]; then
  echo "LocalSend already installed"
else
  brew install --cask localsend
fi

# ---------- helper: (re)load a LaunchAgent ----------
write_agent() {   # $1 = name, $2 = program path, $3 = extra plist keys
  local label="$PREFIX.$1" plist="$AGENTS/$PREFIX.$1.plist"
  launchctl bootout "gui/$UID_NUM/$label" 2>/dev/null || true
  cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key><array><string>$2</string></array>
  <key>RunAtLoad</key><true/>
$3
  <key>StandardOutPath</key><string>$LOGS/$1.log</string>
  <key>StandardErrorPath</key><string>$LOGS/$1.log</string>
</dict></plist>
EOF
  plutil -lint -s "$plist"
  launchctl bootstrap "gui/$UID_NUM" "$plist"
}

# ---------- 2. keyremap ----------
say "2/3  keyremap (Alt+Space, Alt+Tab, Alt+C, Ctrl+A/C/V)"
swiftc -O keyremap/main.swift -o "$BASE/keyremap"
codesign --force -s - "$BASE/keyremap"
write_agent keyremap "$BASE/keyremap" "  <key>KeepAlive</key><true/>"
echo "macOS will ask for Accessibility permission for 'keyremap'."
echo "Allow it in System Settings -> Privacy & Security -> Accessibility, then run:"
echo "  launchctl kickstart -k gui/$UID_NUM/$PREFIX.keyremap"

# ---------- 3. home-autostart ----------
say "3/3  home-autostart"
GW=$(route -n get default 2>/dev/null | awk '/gateway:/{print $2}' || true)
MAC=""
if [ -n "$GW" ]; then
  ping -c1 -t1 "$GW" >/dev/null 2>&1 || true
  MAC=$(arp -n "$GW" 2>/dev/null | awk '{print $4}' || true)
fi
if [ -z "$MAC" ] || [ "$MAC" = "(incomplete)" ]; then
  echo "Could not find a router. Connect to your home network and run this again to set up home-autostart."
  exit 0
fi
read -r -p "Is the network you are on now your home network? [y/N] " answer
if [[ ! "$answer" =~ ^[YyJj] ]]; then
  echo "Skipped. Run this again from your home network to set it up."
  exit 0
fi
cat > "$BASE/home.conf" <<EOF
# Router MAC address of the home network (found by install.sh)
HOME_ROUTER_MAC="$MAC"
# Apps to open at home and quit elsewhere
APPS=("Deskflow" "LocalSend")
EOF
cp home-autostart/home-autostart.sh "$BASE/home-autostart.sh"
chmod +x "$BASE/home-autostart.sh"
rm -f "$BASE/state"
write_agent home-autostart "$BASE/home-autostart.sh" "  <key>WatchPaths</key><array><string>/Library/Preferences/SystemConfiguration</string><string>/var/run/resolv.conf</string></array>
  <key>StartInterval</key><integer>300</integer>
  <key>ThrottleInterval</key><integer>10</integer>"

say "Done."
echo "Settings: $BASE/home.conf"
echo "Logs:     $LOGS"
echo "Remove:   ./uninstall.sh"
