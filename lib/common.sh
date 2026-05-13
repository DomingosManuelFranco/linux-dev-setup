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
  # Only install if not already present — avoid reinstalling on every run
  pipx list 2>/dev/null | grep -q 'poetry' || pipx install poetry >/dev/null 2>&1 || warn "poetry install via pipx failed"
  pipx list 2>/dev/null | grep -q 'checkov' || pipx install checkov >/dev/null 2>&1 || warn "checkov install via pipx failed"
  # fastlane requires Ruby; install only if gem is available
  if have gem; then
    if ! gem list --installed fastlane >/dev/null 2>&1; then
      gem install fastlane --user-install >/dev/null 2>&1 || warn "fastlane gem install failed; ensure Ruby >= 2.7 is available"
    fi
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
  # Only set default to stable if no toolchain is active yet (preserve nightly/beta setups)
  if have rustup; then
    local active
    active="$(rustup show active-toolchain 2>/dev/null | awk '{print $1}' || true)"
    if [[ -z "$active" || "$active" == "error"* ]]; then
      rustup default stable >/dev/null 2>&1 || warn "rustup default stable failed"
    fi
  fi
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

setup_git() {
  # Skip if git is not installed
  if ! have git; then
    warn "git not found; skipping git configuration"
    return 0
  fi

  # Read existing values as defaults so re-runs are non-destructive
  local current_name current_email
  current_name="$(git config --global user.name 2>/dev/null || true)"
  current_email="$(git config --global user.email 2>/dev/null || true)"

  # Prompt for name
  local git_name
  if [[ -n "$current_name" ]]; then
    printf '[dev-setup] Git user.name [%s]: ' "$current_name"
  else
    printf '[dev-setup] Git user.name: '
  fi
  IFS= read -r git_name
  git_name="${git_name:-$current_name}"

  if [[ -z "$git_name" ]]; then
    warn "No git user.name provided; skipping git configuration"
    return 0
  fi

  # Prompt for email
  local git_email
  if [[ -n "$current_email" ]]; then
    printf '[dev-setup] Git user.email [%s]: ' "$current_email"
  else
    printf '[dev-setup] Git user.email: '
  fi
  IFS= read -r git_email
  git_email="${git_email:-$current_email}"

  if [[ -z "$git_email" ]]; then
    warn "No git user.email provided; skipping git configuration"
    return 0
  fi

  git config --global user.name  "$git_name"
  git config --global user.email "$git_email"

  # Sensible global defaults (only set if not already configured)
  git config --global --get core.editor      >/dev/null 2>&1 || git config --global core.editor      "nvim"
  git config --global --get core.autocrlf    >/dev/null 2>&1 || git config --global core.autocrlf    "input"
  git config --global --get core.pager       >/dev/null 2>&1 || git config --global core.pager       "delta"
  git config --global --get init.defaultBranch >/dev/null 2>&1 || git config --global init.defaultBranch "main"
  git config --global --get pull.rebase      >/dev/null 2>&1 || git config --global pull.rebase      "true"
  git config --global --get push.autoSetupRemote >/dev/null 2>&1 || git config --global push.autoSetupRemote "true"
  git config --global --get rebase.autoStash >/dev/null 2>&1 || git config --global rebase.autoStash "true"
  git config --global --get fetch.prune      >/dev/null 2>&1 || git config --global fetch.prune      "true"
  git config --global --get diff.colorMoved  >/dev/null 2>&1 || git config --global diff.colorMoved  "zebra"

  # delta pager options (only if delta is available)
  if have delta; then
    git config --global --get delta.navigate   >/dev/null 2>&1 || git config --global delta.navigate   "true"
    git config --global --get delta.side-by-side >/dev/null 2>&1 || git config --global delta.side-by-side "true"
    git config --global --get delta.line-numbers >/dev/null 2>&1 || git config --global delta.line-numbers "true"
    git config --global --get merge.conflictstyle >/dev/null 2>&1 || git config --global merge.conflictstyle "diff3"
  fi

  # Useful aliases (skip if already set)
  git config --global --get alias.st   >/dev/null 2>&1 || git config --global alias.st   "status -sb"
  git config --global --get alias.co   >/dev/null 2>&1 || git config --global alias.co   "checkout"
  git config --global --get alias.br   >/dev/null 2>&1 || git config --global alias.br   "branch -vv"
  git config --global --get alias.lg   >/dev/null 2>&1 || git config --global alias.lg   "log --oneline --graph --decorate --all"
  git config --global --get alias.undo >/dev/null 2>&1 || git config --global alias.undo "reset HEAD~1 --mixed"
  git config --global --get alias.wip  >/dev/null 2>&1 || git config --global alias.wip  "!git add -A && git commit -m 'wip'"

  log "Git configured for $git_name <$git_email>"
}

setup_github() {
  # Requires gh (GitHub CLI) in PATH
  if ! have gh; then
    warn "gh (GitHub CLI) not found; skipping GitHub account setup"
    return 0
  fi

  # Check if already authenticated
  if gh auth status >/dev/null 2>&1; then
    local current_user
    current_user="$(gh api user --jq '.login' 2>/dev/null || true)"
    log "GitHub already authenticated as ${current_user:-unknown}; skipping auth"
  else
    log "Starting GitHub authentication (browser or token)…"
    gh auth login --git-protocol ssh --web || \
      gh auth login --git-protocol ssh     || \
      warn "GitHub auth failed; run 'gh auth login' manually"
  fi

  # Generate SSH key if none exists for this machine
  local ssh_key="$HOME/.ssh/id_ed25519"
  if [[ ! -f "$ssh_key" ]]; then
    local git_email
    git_email="$(git config --global user.email 2>/dev/null || true)"

    if [[ -z "$git_email" ]]; then
      printf '[dev-setup] Email for SSH key: '
      IFS= read -r git_email
    fi

    if [[ -n "$git_email" ]]; then
      log "Generating SSH key for $git_email…"
      mkdir -p "$HOME/.ssh"
      chmod 700 "$HOME/.ssh"
      ssh-keygen -t ed25519 -C "$git_email" -f "$ssh_key" -N ""
      log "SSH key generated: $ssh_key"
    else
      warn "No email provided; skipping SSH key generation"
      return 0
    fi
  else
    log "SSH key already exists: $ssh_key"
  fi

  # Upload key to GitHub if gh is authenticated
  if gh auth status >/dev/null 2>&1; then
    local hostname key_title
    hostname="$(hostname -s 2>/dev/null || printf 'linux')"
    key_title="$hostname-ed25519"

    # Check if this exact public key blob is already uploaded (compare base64 field, not just the type)
    local pub_blob
    pub_blob="$(awk '{print $2}' "${ssh_key}.pub")"
    if gh ssh-key list 2>/dev/null | grep -qF "$pub_blob"; then
      log "SSH public key already on GitHub; skipping upload"
    else
      gh ssh-key add "${ssh_key}.pub" --title "$key_title" \
        && log "SSH public key uploaded to GitHub as '$key_title'" \
        || warn "Could not upload SSH key to GitHub; add it manually at https://github.com/settings/ssh/new"
    fi
  fi

  # Ensure SSH agent knows about the key — reuse existing agent, don't spawn a new one
  if [[ -f "$ssh_key" ]]; then
    if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
      # No agent running in this session; start one and export the vars
      eval "$(ssh-agent -s)" 2>/dev/null || true
    fi
    ssh-add "$ssh_key" >/dev/null 2>&1 || true
  fi

  log "GitHub setup complete"
}

setup_browser_mime() {
  # Detect which browser is installed and register it as the default for web MIME types.
  # Runs after link_dotfiles so ~/.config/mimeapps.list already exists as a symlink.
  local browser_desktop=""
  local -A candidates=(
    [google-chrome-stable]=google-chrome.desktop
    [google-chrome]=google-chrome.desktop
    [chromium-browser]=chromium-browser.desktop
    [chromium]=chromium.desktop
    [firefox]=firefox.desktop
    [brave-browser]=brave-browser.desktop
  )

  for bin in google-chrome-stable google-chrome chromium-browser chromium firefox brave-browser; do
    if have "$bin"; then
      browser_desktop="${candidates[$bin]}"
      break
    fi
  done

  if [[ -z "$browser_desktop" ]]; then
    log "No known browser found; skipping web MIME defaults"
    return 0
  fi

  local mimeapps="$HOME/.config/mimeapps.list"
  if [[ ! -f "$mimeapps" ]]; then
    mkdir -p "$HOME/.config"
    printf '[Default Applications]\n' > "$mimeapps"
  fi

  # Update or add each MIME type — sed-in-place approach
  local -a mime_types=(text/html x-scheme-handler/http x-scheme-handler/https x-scheme-handler/about x-scheme-handler/unknown)
  for mime in "${mime_types[@]}"; do
    if grep -q "^${mime}=" "$mimeapps" 2>/dev/null; then
      sed -i "s|^${mime}=.*|${mime}=${browser_desktop}|" "$mimeapps"
    else
      printf '%s=%s\n' "$mime" "$browser_desktop" >> "$mimeapps"
    fi
  done

  log "Set default browser MIME types to $browser_desktop"
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
