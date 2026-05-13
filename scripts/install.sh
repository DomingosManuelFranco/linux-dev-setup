#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=../lib/common.sh
source "$REPO_ROOT/lib/common.sh"
# shellcheck source=../lib/packages.sh
source "$REPO_ROOT/lib/packages.sh"
# shellcheck source=../lib/vendor.sh
source "$REPO_ROOT/lib/vendor.sh"

DESKTOP=""
INSTALL_OPTIONAL=0
INSTALL_VENDOR=1
ROLES=(base web mobile devops)

detect_desktop() {
  local current_desktop session_desktop session

  current_desktop="${XDG_CURRENT_DESKTOP:-}"
  session_desktop="${DESKTOP_SESSION:-}"
  session="${XDG_SESSION_DESKTOP:-}"

  case "${current_desktop,,}:${session_desktop,,}:${session,,}" in
    *gnome*:*:*|*:*gnome*:*|*:*:*gnome*)
      printf 'gnome\n'
      return 0
      ;;
    *kde*:*:*|*plasma*:*:*|*:*kde*:*|*:*plasma*:*|*:*:*kde*|*:*:*plasma*)
      printf 'kde\n'
      return 0
      ;;
  esac

  return 1
}

parse_roles() {
  local role_csv="$1"
  local raw role
  local -a parsed=()

  IFS=',' read -r -a raw <<< "$role_csv"
  for role in "${raw[@]}"; do
    case "$role" in
      base|web|mobile|devops)
        parsed+=("$role")
        ;;
      *)
        warn "Unsupported role: $role"
        exit 1
        ;;
    esac
  done

  if [[ ${#parsed[@]} -eq 0 ]]; then
    warn "At least one role must be selected"
    exit 1
  fi

  ROLES=("${parsed[@]}")
}

dedupe_packages() {
  local pkg
  declare -A seen=()
  for pkg in "$@"; do
    [[ -z "$pkg" ]] && continue
    if [[ -z "${seen[$pkg]:-}" ]]; then
      seen[$pkg]=1
      printf '%s\n' "$pkg"
    fi
  done
}

collect_packages() {
  local distro="$1"
  local -a selected=()
  local role

  for role in "${ROLES[@]}"; do
    while IFS= read -r package; do
      [[ -n "$package" ]] && selected+=("$package")
    done < <(resolve_packages "$distro" "$role")
  done

  if [[ "$INSTALL_OPTIONAL" -eq 1 ]]; then
    while IFS= read -r package; do
      [[ -n "$package" ]] && selected+=("$package")
    done < <(resolve_packages "$distro" gui)
  fi

  dedupe_packages "${selected[@]}"
}

bootstrap_selected_vendors() {
  local role
  if [[ "$INSTALL_VENDOR" -ne 1 ]]; then
    return 0
  fi

  for role in "${ROLES[@]}"; do
    bootstrap_role_vendors "$role"
  done

  if [[ "$INSTALL_OPTIONAL" -eq 1 ]]; then
    bootstrap_optional_vendors
  fi
}

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
    --roles)
      parse_roles "${2:-}"
      shift 2
      ;;
    --no-vendor)
      INSTALL_VENDOR=0
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage: ./scripts/install.sh [--desktop gnome|kde] [--roles base,web,mobile,devops] [--optional] [--no-vendor]

  --desktop    apply optional desktop-specific settings
  --roles      comma-separated install roles; defaults to base,web,mobile,devops
  --optional   also attempt GUI packages like VS Code, Chrome, Android Studio, and Podman Desktop
  --no-vendor  skip vendor bootstraps like mise, Flutter SDK, and Android SDK components
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

if [[ -z "$DESKTOP" ]] && detected_desktop="$(detect_desktop 2>/dev/null)"; then
  DESKTOP="$detected_desktop"
fi

log "Detected distro: $distro"
log "Selected roles: ${ROLES[*]}"
if [[ -n "$DESKTOP" ]]; then
  log "Detected desktop profile: $DESKTOP"
fi

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
  mapfile -t packages < <(collect_packages arch)
  mapfile -t filtered < <(filter_arch_packages "${packages[@]}")
  if [[ ${#filtered[@]} -gt 0 ]]; then
    sudo pacman -Syu --needed --noconfirm "${filtered[@]}"
  fi
}

install_fedora() {
  local -a packages=() filtered=()
  mapfile -t packages < <(collect_packages fedora)
  mapfile -t filtered < <(filter_fedora_packages "${packages[@]}")
  if [[ ${#filtered[@]} -gt 0 ]]; then
    sudo dnf install -y "${filtered[@]}"
  fi
}

install_apt_like() {
  local distro_name="$1"
  local -a packages=() filtered=()
  sudo apt-get update
  mapfile -t packages < <(collect_packages "$distro_name")
  mapfile -t filtered < <(filter_apt_packages "${packages[@]}")
  if [[ ${#filtered[@]} -gt 0 ]]; then
    sudo apt-get install -y "${filtered[@]}"
  fi
}

install_opensuse() {
  local -a packages=() filtered=()
  mapfile -t packages < <(collect_packages opensuse)
  mapfile -t filtered < <(filter_zypper_packages "${packages[@]}")
  if [[ ${#filtered[@]} -gt 0 ]]; then
    sudo zypper --non-interactive install --no-recommends "${filtered[@]}"
  fi
}

case "$distro" in
  arch) install_arch ;;
  fedora) install_fedora ;;
  ubuntu) install_apt_like ubuntu ;;
  debian) install_apt_like debian ;;
  pikaos) install_apt_like pikaos ;;
  opensuse) install_opensuse ;;
esac

link_dotfiles
render_templates
bootstrap_selected_vendors
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
