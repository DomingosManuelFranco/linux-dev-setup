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
SETUP_GIT=1
SETUP_GITHUB=1
NON_INTERACTIVE=0
SKIP_SHELL_CHANGE=0
GIT_NAME=""
GIT_EMAIL=""
ROLES=(base)

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
  local pkg mapped

  for role in "${ROLES[@]}"; do
    while IFS= read -r pkg; do
      [[ -z "$pkg" ]] && continue
      if mapped="$(map_package "$distro" "$pkg" 2>/dev/null)"; then
        [[ -n "$mapped" ]] && selected+=("$mapped")
      else
        record_required_pkg_failure "$pkg"
      fi
    done < <(package_group "$role")
  done

  if [[ "$INSTALL_OPTIONAL" -eq 1 ]]; then
    while IFS= read -r pkg; do
      [[ -z "$pkg" ]] && continue
      if mapped="$(map_package "$distro" "$pkg" 2>/dev/null)"; then
        [[ -n "$mapped" ]] && selected+=("$mapped")
      else
        record_optional_failure "$pkg"
      fi
    done < <(package_group gui)
  fi

  if [[ "${DESKTOP:-}" == "gnome" ]]; then
    while IFS= read -r pkg; do
      [[ -z "$pkg" ]] && continue
      if mapped="$(map_package "$distro" "$pkg" 2>/dev/null)"; then
        [[ -n "$mapped" ]] && selected+=("$mapped")
      else
        record_required_pkg_failure "$pkg"
      fi
    done < <(package_group gnome)
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
    --non-interactive)
      NON_INTERACTIVE=1
      shift
      ;;
    --git-name)
      GIT_NAME="${2:-}"
      shift 2
      ;;
    --git-email)
      GIT_EMAIL="${2:-}"
      shift 2
      ;;
    --skip-shell-change)
      SKIP_SHELL_CHANGE=1
      shift
      ;;
    --no-vendor)
      INSTALL_VENDOR=0
      shift
      ;;
    --no-git)
      SETUP_GIT=0
      shift
      ;;
    --no-github)
      SETUP_GITHUB=0
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage: ./scripts/install.sh [--desktop gnome|kde] [--roles base,web,mobile,devops] [--optional] [--no-vendor] [--no-git] [--no-github] [--non-interactive] [--git-name NAME] [--git-email EMAIL] [--skip-shell-change]

  --desktop            apply optional desktop-specific settings
  --roles              comma-separated install roles; default is 'base' only
  --optional           also attempt GUI packages
  --no-vendor          skip vendor bootstraps
  --no-git             skip git user configuration
  --no-github          skip GitHub authentication and SSH key setup
  --non-interactive    run without prompting for input
  --git-name NAME      set git user.name
  --git-email EMAIL    set git user.email
  --skip-shell-change  do not attempt to chsh to zsh

  --desktop    apply optional desktop-specific settings
  --roles      comma-separated install roles; default is 'base' only
               use --roles base,web,mobile,devops to install everything
  --optional   also attempt GUI packages like VS Code, Chrome, JetBrains Toolbox, and Podman Desktop
  --no-vendor  skip vendor bootstraps like mise, Flutter SDK, and Android SDK components
  --no-git     skip interactive git user configuration
  --no-github  skip GitHub authentication and SSH key setup
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

# Tee all output to a log file for post-mortem debugging
LOG_FILE="$HOME/.local/share/dev-setup-portable/install-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

log "Detected distro: $distro"
log "Selected roles: ${ROLES[*]}"
log "Log file: $LOG_FILE"
if [[ -n "$DESKTOP" ]]; then
  log "Detected desktop profile: $DESKTOP"
fi
log "Optional GUI apps: $INSTALL_OPTIONAL"
log "Vendor tools: $INSTALL_VENDOR"
log "Non-interactive: $NON_INTERACTIVE"

filter_arch_packages() {
  filtered=()
  for pkg in "$@"; do
    if pacman -Si "$pkg" >/dev/null 2>&1; then
      filtered+=("$pkg")
    else
      warn "Skipping unavailable package: $pkg"
      record_required_pkg_failure "$pkg"
    fi
  done
}

filter_fedora_packages() {
  filtered=()
  for pkg in "$@"; do
    if dnf info "$pkg" >/dev/null 2>&1; then
      filtered+=("$pkg")
    else
      warn "Skipping unavailable package: $pkg"
      record_required_pkg_failure "$pkg"
    fi
  done
}

filter_apt_packages() {
  filtered=()
  for pkg in "$@"; do
    if apt-cache show "$pkg" >/dev/null 2>&1; then
      filtered+=("$pkg")
    else
      warn "Skipping unavailable package: $pkg"
      record_required_pkg_failure "$pkg"
    fi
  done
}

filter_zypper_packages() {
  filtered=()
  for pkg in "$@"; do
    if zypper --non-interactive search --match-exact "$pkg" | grep -Eq "^[[:space:]]*[ivp][[:space:]]*\|"; then
      filtered+=("$pkg")
    else
      warn "Skipping unavailable package: $pkg"
      record_required_pkg_failure "$pkg"
    fi
  done
}

install_arch() {
  local -a packages=()
  mapfile -t packages < <(collect_packages arch)
  filter_arch_packages "${packages[@]}"
  if [[ ${#filtered[@]} -gt 0 ]]; then
    sudo pacman -Syu --needed --noconfirm "${filtered[@]}"
  fi
}

install_fedora() {
  local -a packages=()
  mapfile -t packages < <(collect_packages fedora)
  filter_fedora_packages "${packages[@]}"
  if [[ ${#filtered[@]} -gt 0 ]]; then
    sudo dnf install -y "${filtered[@]}"
  fi
}

install_apt_like() {
  local distro_name="$1"
  local -a packages=()
  sudo apt-get update
  mapfile -t packages < <(collect_packages "$distro_name")
  filter_apt_packages "${packages[@]}"
  if [[ ${#filtered[@]} -gt 0 ]]; then
    sudo apt-get install -y "${filtered[@]}"
  fi
}

install_opensuse() {
  local -a packages=()
  mapfile -t packages < <(collect_packages opensuse)
  filter_zypper_packages "${packages[@]}"
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
setup_browser_mime
bootstrap_selected_vendors
setup_corepack
setup_pipx
# gext must be installed after pipx ensurepath so it lands on PATH
install_gext
setup_rust
install_npm_globals
install_vscode_extensions
enable_systemd_units

if [[ "$SETUP_GIT" -eq 1 ]]; then
  setup_git
fi

if [[ "$SETUP_GITHUB" -eq 1 ]]; then
  setup_github
fi

if [[ "$SKIP_SHELL_CHANGE" -eq 0 && "$NON_INTERACTIVE" -eq 0 ]]; then
  if have chsh && have zsh; then
    if [[ "${SHELL:-}" != "$(command -v zsh)" ]]; then
      chsh -s "$(command -v zsh)" || warn "Could not change default shell"
    fi
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


verify_post_install

print_final_summary
