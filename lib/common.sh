#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES_ROOT="$REPO_ROOT/config/home"
BACKUP_ROOT="$HOME/.local/share/dev-setup-portable/backups"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

log() {
  printf '[dev-setup] %s\n' "$*"
}

warn() {
  printf '[dev-setup] warning: %s\n' "$*" >&2
}

have() {
  command -v "$1" >/dev/null 2>&1
}

ensure_backup_dir() {
  mkdir -p "$BACKUP_ROOT/$TIMESTAMP"
}

backup_if_conflict() {
  local target="$1"

  if [[ -L "$target" ]]; then
    return 0
  fi

  if [[ -e "$target" ]]; then
    ensure_backup_dir
    local rel
    rel="${target#$HOME/}"
    mkdir -p "$BACKUP_ROOT/$TIMESTAMP/$(dirname "$rel")"
    mv "$target" "$BACKUP_ROOT/$TIMESTAMP/$rel"
    log "Backed up $target"
  fi
}

link_one() {
  local source="$1"
  local target="$2"

  mkdir -p "$(dirname "$target")"
  backup_if_conflict "$target"
  ln -sfn "$source" "$target"
  log "Linked $target"
}

link_dotfiles() {
  while IFS= read -r -d '' source; do
    local rel target
    rel="${source#$DOTFILES_ROOT/}"
    target="$HOME/$rel"
    link_one "$source" "$target"
  done < <(find "$DOTFILES_ROOT" \( -type f -o -type l \) -print0)
}

render_templates() {
  local templates_root="$REPO_ROOT/config/templates"

  if [[ ! -d "$templates_root" ]]; then
    return 0
  fi

  while IFS= read -r -d '' template; do
    local rel target_dir target
    rel="${template#$templates_root/}"
    target_dir="$HOME/$(dirname "$rel")"
    target="$HOME/${rel%.tmpl}"

    mkdir -p "$target_dir"
    backup_if_conflict "$target"

    sed \
      -e "s|@@HOME@@|$HOME|g" \
      -e "s|@@USER@@|${USER:-}|g" \
      "$template" > "$target"

    log "Rendered $target"
  done < <(find "$templates_root" -type f -name '*.tmpl' -print0)
}

enable_systemd_units() {
  if have systemctl; then
    if systemctl list-unit-files docker.service >/dev/null 2>&1; then
      sudo systemctl enable --now docker.service || warn "Unable to enable docker.service"
    fi

    systemctl --user enable --now podman.socket >/dev/null 2>&1 || true
  fi
}

setup_corepack() {
  corepack enable >/dev/null 2>&1 || true
  corepack prepare pnpm@latest --activate >/dev/null 2>&1 || true
}

setup_pipx() {
  pipx ensurepath >/dev/null 2>&1 || true
  pipx install --force poetry >/dev/null 2>&1 || true
  pipx install --force checkov >/dev/null 2>&1 || true
  # fastlane requires Ruby; install only if gem is available
  if have gem; then
    gem install fastlane --user-install >/dev/null 2>&1 || warn "fastlane gem install failed; ensure Ruby >= 2.7 is available"
  else
    warn "gem not found; skipping fastlane — install Ruby then run: gem install fastlane"
  fi
}

setup_rust() {
  # Source cargo env in case rustup was just installed this session
  if [[ -f "$HOME/.cargo/env" ]]; then
    # shellcheck source=/dev/null
    . "$HOME/.cargo/env"
  fi
  rustup default stable >/dev/null 2>&1 || true
}

install_vscode_extensions() {
  local code_bin=""

  if have code; then
    code_bin="code"
  elif have codium; then
    code_bin="codium"
  fi

  if [[ -z "$code_bin" ]]; then
    warn "VS Code binary not found; skipping extension install"
    return 0
  fi

  local ext_file="$REPO_ROOT/config/vscode/extensions.txt"
  if [[ ! -f "$ext_file" ]]; then
    warn "VS Code extensions file not found: $ext_file"
    return 0
  fi

  while IFS= read -r extension; do
    [[ -z "$extension" || "$extension" == \#* ]] && continue
    "$code_bin" --install-extension "$extension" >/dev/null 2>&1 || warn "Failed to install VS Code extension $extension"
  done < "$ext_file"
}

install_npm_globals() {
  local globals_file="$REPO_ROOT/config/npm/globals.txt"

  if ! have npm; then
    warn "npm not found; skipping global npm packages"
    return 0
  fi

  if [[ ! -f "$globals_file" ]]; then
    warn "npm globals file not found: $globals_file"
    return 0
  fi

  mkdir -p "$HOME/.local/bin"
  npm config set prefix "$HOME/.local" >/dev/null 2>&1 || true

  local -a globals=()
  while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" == \#* ]] && continue
    globals+=("$pkg")
  done < "$globals_file"

  if [[ ${#globals[@]} -gt 0 ]]; then
    npm install -g "${globals[@]}" >/dev/null 2>&1 || true
  fi
}
