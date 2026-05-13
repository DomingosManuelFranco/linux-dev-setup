#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[dev-setup][gnome] %s\n' "$*"
}

warn() {
  printf '[dev-setup][gnome] warning: %s\n' "$*" >&2
}

if ! command -v gsettings >/dev/null 2>&1; then
  warn "gsettings not found; skipping GNOME settings"
  exit 0
fi

gsettings set org.gnome.desktop.interface color-scheme prefer-dark || true
gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 11' || true
gsettings set org.gnome.desktop.default-applications.terminal exec 'kitty' || true
gsettings set org.gnome.shell favorite-apps "['org.gnome.Nautilus.desktop', 'kitty.desktop', 'code.desktop', 'google-chrome.desktop']" || true

log "Applied GNOME defaults"
