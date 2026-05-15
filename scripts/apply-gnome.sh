#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../lib/common.sh
source "$REPO_ROOT/lib/common.sh"

# Override log/warn prefix for GNOME context
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

install_gnome_extensions() {
  local extension installer_bin uuid
  local extension_list="$REPO_ROOT/config/gnome/extensions.txt"

  if [[ ! -f "$extension_list" ]]; then
    return 0
  fi

  if ! command -v gnome-extensions >/dev/null 2>&1; then
    warn "gnome-extensions not found; skipping extension install"
    return 0
  fi

  if command -v gext >/dev/null 2>&1; then
    installer_bin="gext"
  fi

  while IFS= read -r uuid; do
    [[ -z "$uuid" ]] && continue

    if gnome-extensions info "$uuid" >/dev/null 2>&1; then
      gnome-extensions enable "$uuid" >/dev/null 2>&1 || warn "Failed to enable $uuid"
      continue
    fi

    if [[ -n "${installer_bin:-}" ]]; then
      # gnome-extensions-cli (pipx install gnome-extensions-cli) uses: gext install <uuid>
      gext install "$uuid" >/dev/null 2>&1 || warn "Failed to install $uuid via gext; install manually with Extension Manager"
    else
      warn "gext not found; install $uuid manually with Extension Manager"
    fi

    gnome-extensions enable "$uuid" >/dev/null 2>&1 || true
  done < "$extension_list"
}

gsettings set org.gnome.desktop.interface color-scheme prefer-dark || true
gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 11' || true

resolve_terminal() {
  if command -v kitty >/dev/null 2>&1; then
    printf 'kitty|kitty.desktop|%s\n' "$(command -v kitty)"
    return 0
  fi

  if command -v alacritty >/dev/null 2>&1; then
    printf 'alacritty|Alacritty.desktop|%s\n' "$(command -v alacritty)"
    return 0
  fi

  return 1
}

# Set default terminal: GNOME 42+ removed the old key; use xdg-mime and update-alternatives
if terminal_info="$(resolve_terminal)"; then
  IFS='|' read -r terminal_exec terminal_desktop terminal_bin <<< "$terminal_info"

  if command -v update-alternatives >/dev/null 2>&1; then
    update-alternatives --set x-terminal-emulator "$terminal_bin" >/dev/null 2>&1 || true
  fi
  if command -v xdg-mime >/dev/null 2>&1; then
    xdg-mime default "$terminal_desktop" x-scheme-handler/terminal >/dev/null 2>&1 || true
  fi
  # Also set the GNOME 40-41 key as a best-effort fallback (silently fails on 42+)
  gsettings set org.gnome.desktop.default-applications.terminal exec "$terminal_exec" 2>/dev/null || true
else
  warn "No supported repo-managed terminal found; skipping default terminal configuration"
fi

# Build a dynamic favorites list based on what is actually installed
build_favorites() {
  local -a favs=()

  # Detect Nautilus .desktop name (differs across distros)
  local nautilus_desktop=""
  for _f in org.gnome.Nautilus.desktop nautilus.desktop; do
    if [[ -f "/usr/share/applications/$_f" ]] || [[ -f "$HOME/.local/share/applications/$_f" ]]; then
      nautilus_desktop="$_f"
      break
    fi
  done
  [[ -n "$nautilus_desktop" ]] && favs+=("$nautilus_desktop")

  if terminal_info="$(resolve_terminal)"; then
    IFS='|' read -r _terminal_exec terminal_desktop _terminal_bin <<< "$terminal_info"
    favs+=("$terminal_desktop")
  fi

  if command -v code >/dev/null 2>&1; then
    favs+=('code.desktop')
  elif command -v codium >/dev/null 2>&1; then
    favs+=('codium.desktop')
  fi

  if command -v google-chrome-stable >/dev/null 2>&1 || command -v google-chrome >/dev/null 2>&1; then
    favs+=('google-chrome.desktop')
  fi

  command -v firefox >/dev/null 2>&1 && favs+=('firefox.desktop')

  # Build gsettings array string
  local joined
  joined="$(printf "'%s', " "${favs[@]}")"
  joined="${joined%, }"
  printf '[%s]\n' "$joined"
}

gsettings set org.gnome.shell favorite-apps "$(build_favorites)" || true

install_gnome_extensions

log "Applied GNOME defaults"
