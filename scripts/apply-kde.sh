#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../lib/common.sh
source "$REPO_ROOT/lib/common.sh"

# Override log/warn prefix for KDE context
log() {
  printf '[dev-setup][kde] %s\n' "$*"
}

warn() {
  printf '[dev-setup][kde] warning: %s\n' "$*" >&2
}

# Copy color scheme
if [[ -f "$REPO_ROOT/assets/kde/DankNight.colors" ]]; then
  mkdir -p "$HOME/.local/share/color-schemes"
  cp "$REPO_ROOT/assets/kde/DankNight.colors" "$HOME/.local/share/color-schemes/DankNight.colors"
  log "Installed DankNight color scheme"
else
  warn "DankNight.colors not found at $REPO_ROOT/assets/kde/DankNight.colors; skipping color scheme"
fi

# Resolve the correct kwriteconfig binary
if command -v kwriteconfig6 >/dev/null 2>&1; then
  kwriteconfig() { kwriteconfig6 "$@"; }
elif command -v kwriteconfig5 >/dev/null 2>&1; then
  kwriteconfig() { kwriteconfig5 "$@"; }
else
  warn "kwriteconfig not found; KDE settings not applied"
  exit 0
fi

kwriteconfig --file kdeglobals --group General --key ColorScheme DankNight || true
kwriteconfig --file klaunchrc --group BusyCursorSettings --key Bouncing false || true

# Set default browser — .desktop file name differs by distro
resolve_chrome_desktop() {
  # Check actual .desktop file presence in common locations
  local dirs=(/usr/share/applications "$HOME/.local/share/applications")
  local name
  for name in google-chrome.desktop google-chrome-stable.desktop chromium.desktop; do
    local dir
    for dir in "${dirs[@]}"; do
      [[ -f "$dir/$name" ]] && printf '%s\n' "$name" && return 0
    done
  done
  # Fallback: check if binary is available and guess
  if command -v google-chrome-stable >/dev/null 2>&1; then
    printf 'google-chrome-stable.desktop\n'
    return 0
  elif command -v google-chrome >/dev/null 2>&1; then
    printf 'google-chrome.desktop\n'
    return 0
  fi
  printf 'firefox.desktop\n'
}

browser_desktop="$(resolve_chrome_desktop)"
kwriteconfig --file kdeglobals --group General --key BrowserApplication "$browser_desktop" || true
log "Set default browser to: $browser_desktop"

# Notify the running KDE session to pick up config changes (if qdbus is available)
reload_kde_config() {
  local qdbus_bin=""
  if command -v qdbus6 >/dev/null 2>&1; then
    qdbus_bin="qdbus6"
  elif command -v qdbus >/dev/null 2>&1; then
    qdbus_bin="qdbus"
  fi

  if [[ -n "$qdbus_bin" ]]; then
    "$qdbus_bin" org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
    "$qdbus_bin" org.kde.plasma.desktop /MainApplication reconfigure >/dev/null 2>&1 || true
    log "Sent reconfigure signal to KDE session"
  else
    warn "qdbus not found; color scheme and settings will apply after next login"
  fi
}

reload_kde_config

# Set monospace font in Konsole profile if available
if command -v kwriteconfig6 >/dev/null 2>&1 || command -v kwriteconfig5 >/dev/null 2>&1; then
  kwriteconfig --file konsolerc --group "Desktop Entry" --key DefaultProfile "Shell.profile" || true
  local_konsole_profiles="$HOME/.local/share/konsole"
  if [[ -d "$local_konsole_profiles" ]]; then
    for profile in "$local_konsole_profiles"/*.profile; do
      [[ -f "$profile" ]] || continue
      kwriteconfig --file "$profile" --group Appearance --key Font "JetBrainsMono Nerd Font,11,-1,5,50,0,0,0,0,0" || true
    done
  fi
fi

log "Applied KDE defaults"
