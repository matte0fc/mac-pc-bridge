#!/bin/bash
# home-autostart
# Opens apps (by default Deskflow + LocalSend) when the Mac joins your home network
# and quits them when it joins any other network.
#
# The home network is recognised by the router's MAC address, which needs no
# Location permission (reading the Wi-Fi name on modern macOS does).
# It only acts when the network changes, so an app you quit yourself at home
# is not reopened behind your back.

BASE="$HOME/Library/Application Support/mac-pc-bridge"
CONF="$BASE/home.conf"
STATE="$BASE/state"
LOG="$HOME/Library/Logs/mac-pc-bridge/home-autostart.log"

# Defaults; home.conf overrides them
HOME_ROUTER_MAC=""
APPS=("Deskflow" "LocalSend")
# shellcheck source=/dev/null
[ -f "$CONF" ] && . "$CONF"

log() { mkdir -p "$(dirname "$LOG")"; echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"; }

[ -z "$HOME_ROUTER_MAC" ] && { log "HOME_ROUTER_MAC is not set in $CONF"; exit 1; }

sleep 3  # let the network settle after a change
GW=$(route -n get default 2>/dev/null | awk '/gateway:/{print $2}')
[ -z "$GW" ] && exit 0                       # no network at all: do nothing
ping -c1 -t1 "$GW" >/dev/null 2>&1           # make sure the router is in the ARP table
MAC=$(arp -n "$GW" 2>/dev/null | awk '{print $4}')
{ [ -z "$MAC" ] || [ "$MAC" = "(incomplete)" ]; } && exit 0

if [ "$MAC" = "$HOME_ROUTER_MAC" ]; then NOW=home; else NOW=away; fi
PREV=$(cat "$STATE" 2>/dev/null)
[ "$NOW" = "$PREV" ] && exit 0               # same as last time: nothing to do
mkdir -p "$BASE"; echo "$NOW" > "$STATE"

if [ "$NOW" = home ]; then
  log "home network -> opening ${APPS[*]}"
  for a in "${APPS[@]}"; do open -g -j -a "$a"; done
else
  log "other network -> quitting ${APPS[*]}"
  for a in "${APPS[@]}"; do osascript -e "quit app \"$a\"" >/dev/null 2>&1; done
  sleep 2
  # Some apps (LocalSend) refuse a polite quit; Deskflow leaves a helper process
  for a in "${APPS[@]}"; do pkill -f "/$a.app/Contents/MacOS/" 2>/dev/null; done
fi
