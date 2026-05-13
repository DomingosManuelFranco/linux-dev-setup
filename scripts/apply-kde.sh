#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

log() {
  printf '[dev-setup][kde] %s\n' "$*"
}

warn() {
  printf '[dev-setup][kde] warning: %s\n' "$*" >&2
}

mkdir -p "$HOME/.local/share/color-schemes"
cp "$REPO_ROOT/assets/kde/DankNight.colors" "$HOME/.local/share/color-schemes/DankNight.colors"

if command -v kwriteconfig6 >/dev/null 2>&1; then
  kwriteconfig6 --file kdeglobals --group General --key ColorScheme DankNight || true
  kwriteconfig6 --file kdeglobals --group General --key BrowserApplication google-chrome-stable.desktop || true
  kwriteconfig6 --file klaunchrc --group BusyCursorSettings --key Bouncing false || true
elif command -v kwriteconfig5 >/dev/null 2>&1; then
  kwriteconfig5 --file kdeglobals --group General --key ColorScheme DankNight || true
  kwriteconfig5 --file kdeglobals --group General --key BrowserApplication google-chrome-stable.desktop || true
  kwriteconfig5 --file klaunchrc --group BusyCursorSettings --key Bouncing false || true
else
  warn "kwriteconfig not found; color scheme copied but KDE settings not applied"
fi

log "Applied KDE defaults"
