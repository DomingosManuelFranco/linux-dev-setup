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
}

setup_rust() {
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

  while IFS= read -r extension; do
    [[ -z "$extension" ]] && continue
    "$code_bin" --install-extension "$extension" >/dev/null 2>&1 || warn "Failed to install VS Code extension $extension"
  done < "$REPO_ROOT/config/vscode/extensions.txt"
}

install_npm_globals() {
  mkdir -p "$HOME/.local/bin"
  npm config set prefix "$HOME/.local" >/dev/null 2>&1 || true
  npm install -g @react-native-community/cli @biomejs/biome eas-cli eslint_d yarn typescript typescript-language-server vscode-langservers-extracted >/dev/null 2>&1 || true
}
