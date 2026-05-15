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

desktop_file_exists() {
  local desktop_file="$1"
  [[ -f "/usr/share/applications/$desktop_file" || -f "$HOME/.local/share/applications/$desktop_file" ]]
}

resolve_gnome_terminal_desktop() {
  local desktop_file
  for desktop_file in org.gnome.Console.desktop org.gnome.Terminal.desktop kgx.desktop gnome-terminal.desktop; do
    if desktop_file_exists "$desktop_file"; then
      printf '%s\n' "$desktop_file"
      return 0
    fi
  done

  return 1
}

configure_gnome_terminal() {
  if ! command -v gsettings >/dev/null 2>&1; then
    return 0
  fi

  if ! gsettings list-schemas | grep -qx 'org.gnome.Terminal.ProfilesList'; then
    return 0
  fi

  local profile_id profile_path
  profile_id="$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")"
  if [[ -z "$profile_id" ]]; then
    return 0
  fi

  profile_path="/org/gnome/terminal/legacy/profiles:/:${profile_id}/"

  gsettings set org.gnome.Terminal.Legacy.Settings theme-variant 'dark' || true
  gsettings set org.gnome.Terminal.Legacy.Settings confirm-close false || true
  gsettings set org.gnome.Terminal.Legacy.Settings new-terminal-mode 'window' || true
  gsettings set org.gnome.Terminal.Legacy.Settings tab-policy 'automatic' || true

  gsettings set "org.gnome.Terminal.Legacy.Profile:${profile_path}" visible-name 'DankNight' || true
  gsettings set "org.gnome.Terminal.Legacy.Profile:${profile_path}" use-system-font false || true
  gsettings set "org.gnome.Terminal.Legacy.Profile:${profile_path}" font 'JetBrainsMono Nerd Font Mono 12' || true
  gsettings set "org.gnome.Terminal.Legacy.Profile:${profile_path}" use-theme-colors false || true
  gsettings set "org.gnome.Terminal.Legacy.Profile:${profile_path}" foreground-color '#E2E7EA' || true
  gsettings set "org.gnome.Terminal.Legacy.Profile:${profile_path}" background-color '#12161A' || true
  gsettings set "org.gnome.Terminal.Legacy.Profile:${profile_path}" bold-color-same-as-fg true || true
  gsettings set "org.gnome.Terminal.Legacy.Profile:${profile_path}" cursor-shape 'block' || true
  gsettings set "org.gnome.Terminal.Legacy.Profile:${profile_path}" cursor-blink-mode 'on' || true
  gsettings set "org.gnome.Terminal.Legacy.Profile:${profile_path}" scrollbar-policy 'never' || true
  gsettings set "org.gnome.Terminal.Legacy.Profile:${profile_path}" scrollback-lines 3000 || true
  gsettings set "org.gnome.Terminal.Legacy.Profile:${profile_path}" palette "['#12161A', '#F69B6E', '#6BD671', '#FFF372', '#7ACBB9', '#266355', '#8FD6C6', '#D3E0DD', '#808B88', '#FFBF9F', '#A5FFAB', '#FFF7A5', '#A9EBDC', '#C3FFF1', '#D8FFF6', '#F8FFFD']" || true

  log 'Configured GNOME Terminal profile'
}

configure_gnome_terminal

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

  if terminal_desktop="$(resolve_gnome_terminal_desktop)"; then
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
