#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES_ROOT="$REPO_ROOT/config/home"
BACKUP_ROOT="$HOME/.local/share/dev-setup-portable/backups"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

declare -a FAILED_REQUIRED_PKGS=()
declare -a FAILED_VENDOR_TOOLS=()
declare -a FAILED_SETUP=()
declare -a FAILED_OPTIONAL_GUI=()
declare -a WARNINGS=()
declare -a MISSING_COMMANDS=()

record_required_pkg_failure() {
  # Check if it's an optional package before adding to required
  local pkg="$1"
  if [[ "$pkg" == "code" || "$pkg" == "google-chrome-stable" || "$pkg" == "google-chrome" || "$pkg" == "jetbrains-toolbox" || "$pkg" == "podman-desktop" ]]; then
    FAILED_OPTIONAL_GUI+=("$pkg")
  else
    FAILED_REQUIRED_PKGS+=("$pkg")
  fi
}
record_vendor_failure() { FAILED_VENDOR_TOOLS+=("$1"); }
record_setup_failure() { FAILED_SETUP+=("$1"); }
record_optional_failure() { FAILED_OPTIONAL_GUI+=("$1"); }
record_warning() { WARNINGS+=("$1"); }
record_missing_command() { MISSING_COMMANDS+=("$1"); }

verify_command() {
  local cmd="$1"
  if ! have "$cmd"; then
    record_missing_command "$cmd"
  fi
}

verify_post_install() {
  verify_command "git"
  verify_command "fish"
  verify_command "nvim"
  if [[ "$INSTALL_VENDOR" -eq 1 ]]; then
    verify_command "mise"
    verify_command "gh"
  fi
  for role in "${ROLES[@]}"; do
    if [[ "$role" == "web" ]]; then
      verify_command "node"
      verify_command "python"
      if [[ "$INSTALL_VENDOR" -eq 1 ]]; then
        verify_command "mkcert"
        verify_command "mongosh"
        verify_command "usql"
      fi
    elif [[ "$role" == "mobile" ]]; then
      verify_command "adb"
      verify_command "java"
      if [[ "$INSTALL_VENDOR" -eq 1 ]]; then
        verify_command "flutter"
        verify_command "maestro"
        verify_command "bundletool"
        verify_command "flutter_distributor"
      fi
    elif [[ "$role" == "devops" ]]; then
      if ! have "docker" && ! have "podman"; then
        record_missing_command "docker/podman"
      fi
      verify_command "kubectl"
      verify_command "helm"
      verify_command "kustomize"
      verify_command "terraform"
      verify_command "hadolint"
    fi
  done
}

print_final_summary() {
  local failed=0
  echo ""
  log "=== Install Summary ==="
  if [[ ${#FAILED_REQUIRED_PKGS[@]} -gt 0 ]]; then
    log "Failed required packages: ${FAILED_REQUIRED_PKGS[*]}"
    failed=1
  fi
  if [[ ${#FAILED_VENDOR_TOOLS[@]} -gt 0 ]]; then
    log "Failed vendor tools: ${FAILED_VENDOR_TOOLS[*]}"
    failed=1
  fi
  if [[ ${#FAILED_SETUP[@]} -gt 0 ]]; then
    log "Failed setup steps: ${FAILED_SETUP[*]}"
    failed=1
  fi
  if [[ ${#MISSING_COMMANDS[@]} -gt 0 ]]; then
    log "Missing expected commands: ${MISSING_COMMANDS[*]}"
    failed=1
  fi
  if [[ ${#FAILED_OPTIONAL_GUI[@]} -gt 0 ]]; then
    log "Skipped optional GUI packages: ${FAILED_OPTIONAL_GUI[*]}"
  fi
  if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    log "Warnings: ${WARNINGS[*]}"
  fi

  if [[ $failed -eq 1 ]]; then
    log "Install failed due to missing required components."
    exit 1
  else
    log "Install finished successfully."
    if [[ -n "${DESKTOP:-}" ]]; then
      log "Applied desktop profile: $DESKTOP"
    fi
    log "Restart your session so shell and desktop defaults are fully applied"
    exit 0
  fi
}


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
    target="$HOME/.$rel"
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
    target_dir="$HOME/.$(dirname "$rel")"
    target="$HOME/.${rel%.tmpl}"

    mkdir -p "$target_dir"
    if [[ -L "$target" ]]; then
      rm -f "$target"
    fi
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
  if ! have git; then
    warn "git not found; skipping git configuration"
    return 0
  fi

  local current_name current_email
  current_name="$(git config --global user.name 2>/dev/null || true)"
  current_email="$(git config --global user.email 2>/dev/null || true)"

  local git_name="$current_name"
  local git_email="$current_email"

  if [[ "${NON_INTERACTIVE:-0}" -eq 1 ]]; then
    if [[ -n "${GIT_NAME:-}" ]]; then git_name="$GIT_NAME"; fi
    if [[ -n "${GIT_EMAIL:-}" ]]; then git_email="$GIT_EMAIL"; fi
    if [[ -z "$git_name" || -z "$git_email" ]]; then
      warn "Missing --git-name or --git-email in non-interactive mode; skipping git config"
      return 0
    fi
  else
    if [[ -n "$current_name" ]]; then
      printf '[dev-setup] Git user.name [%s]: ' "$current_name"
    else
      printf '[dev-setup] Git user.name: '
    fi
    local input_name
    IFS= read -r input_name
    git_name="${input_name:-$current_name}"

    if [[ -n "$current_email" ]]; then
      printf '[dev-setup] Git user.email [%s]: ' "$current_email"
    else
      printf '[dev-setup] Git user.email: '
    fi
    local input_email
    IFS= read -r input_email
    git_email="${input_email:-$current_email}"
  fi

  if [[ -z "$git_name" || -z "$git_email" ]]; then
    warn "Incomplete git user config provided; skipping"
    return 0
  fi

  git config --global user.name  "$git_name"
  git config --global user.email "$git_email"

  git config --global --get core.editor      >/dev/null 2>&1 || git config --global core.editor      "nvim"
  git config --global --get core.autocrlf    >/dev/null 2>&1 || git config --global core.autocrlf    "input"
  git config --global --get core.pager       >/dev/null 2>&1 || git config --global core.pager       "delta"
  git config --global --get init.defaultBranch >/dev/null 2>&1 || git config --global init.defaultBranch "main"
  git config --global --get pull.rebase      >/dev/null 2>&1 || git config --global pull.rebase      "true"
  git config --global --get push.autoSetupRemote >/dev/null 2>&1 || git config --global push.autoSetupRemote "true"
  git config --global --get rebase.autoStash >/dev/null 2>&1 || git config --global rebase.autoStash "true"
  git config --global --get fetch.prune      >/dev/null 2>&1 || git config --global fetch.prune      "true"
  git config --global --get diff.colorMoved  >/dev/null 2>&1 || git config --global diff.colorMoved  "zebra"

  if have delta; then
    git config --global --get delta.navigate   >/dev/null 2>&1 || git config --global delta.navigate   "true"
    git config --global --get delta.side-by-side >/dev/null 2>&1 || git config --global delta.side-by-side "true"
    git config --global --get delta.line-numbers >/dev/null 2>&1 || git config --global delta.line-numbers "true"
    git config --global --get merge.conflictstyle >/dev/null 2>&1 || git config --global merge.conflictstyle "diff3"
  fi

  git config --global --get alias.st   >/dev/null 2>&1 || git config --global alias.st   "status -sb"
  git config --global --get alias.co   >/dev/null 2>&1 || git config --global alias.co   "checkout"
  git config --global --get alias.br   >/dev/null 2>&1 || git config --global alias.br   "branch -vv"
  git config --global --get alias.lg   >/dev/null 2>&1 || git config --global alias.lg   "log --oneline --graph --decorate --all"
  git config --global --get alias.undo >/dev/null 2>&1 || git config --global alias.undo "reset HEAD~1 --mixed"
  git config --global --get alias.wip  >/dev/null 2>&1 || git config --global alias.wip  "!git add -A && git commit -m 'wip'"

  log "Git configured for $git_name <$git_email>"
}

setup_github() {
  if ! have gh; then
    record_setup_failure "gh (GitHub CLI) not found"
    return 0
  fi

  if gh auth status >/dev/null 2>&1; then
    local current_user
    current_user="$(gh api user --jq '.login' 2>/dev/null || true)"
    log "GitHub already authenticated as ${current_user:-unknown}; skipping auth"
  else
    if [[ "${NON_INTERACTIVE:-0}" -eq 1 ]]; then
      local github_token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
      if [[ -n "$github_token" ]]; then
        log "GitHub token found; authenticating GitHub CLI..."
        if ! printf '%s\n' "$github_token" | gh auth login --git-protocol ssh --with-token >/dev/null 2>&1; then
          record_setup_failure "GitHub non-interactive auth failed with provided token"
          return 0
        fi
      else
        record_setup_failure "GitHub non-interactive auth failed: no GH_TOKEN provided"
        return 0
      fi
    else
      log "Starting GitHub authentication (browser or token)…"
      if ! (gh auth login --git-protocol ssh --web || gh auth login --git-protocol ssh); then
        record_setup_failure "GitHub auth failed"
        return 0
      fi
    fi
  fi

  local ssh_key="$HOME/.ssh/id_ed25519"
  if [[ ! -f "$ssh_key" ]]; then
    local git_email
    git_email="$(git config --global user.email 2>/dev/null || true)"

    if [[ "${NON_INTERACTIVE:-0}" -eq 0 && -z "$git_email" ]]; then
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
      record_warning "No email provided; skipping SSH key generation"
      return 0
    fi
  else
    log "SSH key already exists: $ssh_key"
  fi

  if gh auth status >/dev/null 2>&1; then
    local hostname key_title
    hostname="$(hostname -s 2>/dev/null || printf 'linux')"
    key_title="$hostname-ed25519"

    local pub_blob
    pub_blob="$(awk '{print $2}' "${ssh_key}.pub" 2>/dev/null || true)"
    local ssh_key_list_output
    ssh_key_list_output="$(gh ssh-key list 2>&1 || true)"
    if [[ -n "$pub_blob" ]] && grep -qF "$pub_blob" <<< "$ssh_key_list_output"; then
      log "SSH public key already on GitHub; skipping upload"
    elif grep -q "admin:public_key" <<< "$ssh_key_list_output"; then
      record_warning "GitHub token lacks admin:public_key scope; skipping SSH key upload. Run: gh auth refresh -h github.com -s admin:public_key"
      warn "GitHub token lacks admin:public_key scope; skipping SSH key upload"
    else
      local ssh_key_add_output
      ssh_key_add_output="$(gh ssh-key add "${ssh_key}.pub" --title "$key_title" 2>&1 || true)"
      if [[ -z "$ssh_key_add_output" ]]; then
        log "SSH public key uploaded to GitHub as '$key_title'"
      elif grep -q "admin:public_key" <<< "$ssh_key_add_output"; then
        record_warning "GitHub token lacks admin:public_key scope; skipping SSH key upload. Run: gh auth refresh -h github.com -s admin:public_key"
        warn "GitHub token lacks admin:public_key scope; skipping SSH key upload"
      else
        record_setup_failure "Could not upload SSH key to GitHub"
      fi
    fi
  fi

  if [[ -f "$ssh_key" ]]; then
    if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
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
