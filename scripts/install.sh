#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../lib/common.sh
source "$REPO_ROOT/lib/common.sh"
# shellcheck source=../lib/packages.sh
source "$REPO_ROOT/lib/packages.sh"

DESKTOP=""
INSTALL_OPTIONAL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --desktop)
      DESKTOP="${2:-}"
      shift 2
      ;;
    --optional)
      INSTALL_OPTIONAL=1
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage: ./scripts/install.sh [--desktop gnome|kde] [--optional]

  --desktop   apply optional desktop-specific settings
  --optional  also attempt optional packages like VS Code and Chrome
EOF
      exit 0
      ;;
    *)
      warn "Unknown argument: $1"
      exit 1
      ;;
  esac
done

if ! distro="$(detect_distro)"; then
  warn "Unsupported distro"
  exit 1
fi

log "Detected distro: $distro"

filter_arch_packages() {
  local pkg available=()
  for pkg in "$@"; do
    if pacman -Si "$pkg" >/dev/null 2>&1; then
      available+=("$pkg")
    else
      warn "Skipping unavailable package: $pkg"
    fi
  done
  printf '%s\n' "${available[@]}"
}

filter_fedora_packages() {
  local pkg available=()
  for pkg in "$@"; do
    if dnf info "$pkg" >/dev/null 2>&1; then
      available+=("$pkg")
    else
      warn "Skipping unavailable package: $pkg"
    fi
  done
  printf '%s\n' "${available[@]}"
}

filter_apt_packages() {
  local pkg available=()
  for pkg in "$@"; do
    if apt-cache show "$pkg" >/dev/null 2>&1; then
      available+=("$pkg")
    else
      warn "Skipping unavailable package: $pkg"
    fi
  done
  printf '%s\n' "${available[@]}"
}

filter_zypper_packages() {
  local pkg available=()
  for pkg in "$@"; do
    if zypper --non-interactive search --match-exact "$pkg" | grep -Eq '^[[:space:]]*[ivp][[:space:]]*\|'; then
      available+=("$pkg")
    else
      warn "Skipping unavailable package: $pkg"
    fi
  done
  printf '%s\n' "${available[@]}"
}

install_arch() {
  local -a packages=() filtered=()
  mapfile -t packages < <(resolve_packages arch base)
  mapfile -t filtered < <(filter_arch_packages "${packages[@]}")
  if [[ ${#filtered[@]} -gt 0 ]]; then
    sudo pacman -Syu --needed --noconfirm "${filtered[@]}"
  fi

  if [[ "$INSTALL_OPTIONAL" -eq 1 ]]; then
    if have yay; then
      local -a optional=() filtered_optional=()
      mapfile -t optional < <(resolve_packages arch optional)
      mapfile -t filtered_optional < <(printf '%s\n' "${optional[@]}")
      if [[ ${#filtered_optional[@]} -gt 0 ]]; then
        yay -S --needed --noconfirm "${filtered_optional[@]}" || warn "Some optional AUR packages failed"
      fi
    else
      warn "yay not found; skipping Arch optional packages"
    fi
  fi
}

install_fedora() {
  local -a packages=() filtered=()
  mapfile -t packages < <(resolve_packages fedora base)
  mapfile -t filtered < <(filter_fedora_packages "${packages[@]}")
  if [[ ${#filtered[@]} -gt 0 ]]; then
    sudo dnf install -y "${filtered[@]}"
  fi

  if [[ "$INSTALL_OPTIONAL" -eq 1 ]]; then
    local -a optional=() filtered_optional=()
    mapfile -t optional < <(resolve_packages fedora optional)
    mapfile -t filtered_optional < <(filter_fedora_packages "${optional[@]}")
    if [[ ${#filtered_optional[@]} -gt 0 ]]; then
      sudo dnf install -y "${filtered_optional[@]}" || warn "Some optional Fedora packages failed"
    fi
  fi
}

install_ubuntu_like() {
  local distro_name="$1"
  local -a packages=() filtered=()
  sudo apt-get update
  mapfile -t packages < <(resolve_packages "$distro_name" base)
  mapfile -t filtered < <(filter_apt_packages "${packages[@]}")
  if [[ ${#filtered[@]} -gt 0 ]]; then
    sudo apt-get install -y "${filtered[@]}"
  fi

  if [[ "$INSTALL_OPTIONAL" -eq 1 ]]; then
    local -a optional=() filtered_optional=()
    mapfile -t optional < <(resolve_packages "$distro_name" optional)
    mapfile -t filtered_optional < <(filter_apt_packages "${optional[@]}")
    if [[ ${#filtered_optional[@]} -gt 0 ]]; then
      sudo apt-get install -y "${filtered_optional[@]}" || warn "Some optional apt packages failed"
    fi
  fi
}

install_opensuse() {
  local -a packages=() filtered=()
  mapfile -t packages < <(resolve_packages opensuse base)
  mapfile -t filtered < <(filter_zypper_packages "${packages[@]}")
  if [[ ${#filtered[@]} -gt 0 ]]; then
    sudo zypper --non-interactive install --no-recommends "${filtered[@]}"
  fi

  if [[ "$INSTALL_OPTIONAL" -eq 1 ]]; then
    local -a optional=() filtered_optional=()
    mapfile -t optional < <(resolve_packages opensuse optional)
    mapfile -t filtered_optional < <(filter_zypper_packages "${optional[@]}")
    if [[ ${#filtered_optional[@]} -gt 0 ]]; then
      sudo zypper --non-interactive install --no-recommends "${filtered_optional[@]}" || warn "Some optional openSUSE packages failed"
    fi
  fi
}

case "$distro" in
  arch) install_arch ;;
  fedora) install_fedora ;;
  ubuntu) install_ubuntu_like ubuntu ;;
  pikaos) install_ubuntu_like pikaos ;;
  opensuse) install_opensuse ;;
esac

link_dotfiles
render_templates
setup_corepack
setup_pipx
setup_rust
install_npm_globals
install_vscode_extensions
enable_systemd_units

if have chsh && have zsh; then
  if [[ "${SHELL:-}" != "$(command -v zsh)" ]]; then
    chsh -s "$(command -v zsh)" || warn "Could not change default shell"
  fi
fi

case "$DESKTOP" in
  gnome)
    "$REPO_ROOT/scripts/apply-gnome.sh"
    ;;
  kde)
    "$REPO_ROOT/scripts/apply-kde.sh"
    ;;
  "")
    ;;
  *)
    warn "Unsupported desktop profile: $DESKTOP"
    exit 1
    ;;
esac

log "Install finished"
if [[ -n "$DESKTOP" ]]; then
  log "Applied desktop profile: $DESKTOP"
fi
log "Restart your session so shell and desktop defaults are fully applied"
