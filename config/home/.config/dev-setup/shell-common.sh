#!/usr/bin/env bash

# Helper: add a directory to PATH only if not already present
_prepend_path() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  case ":$PATH:" in
    *":$dir:"*) ;;
    *) export PATH="$dir:$PATH" ;;
  esac
}

_prepend_path "$HOME/.opencode/bin"
_prepend_path "$HOME/.local/bin"
_prepend_path "$HOME/go/bin"
_prepend_path "$HOME/.local/share/mise/shims"
_prepend_path "$HOME/.local/share/mise/bin"
_prepend_path "$HOME/.atuin/bin"
_prepend_path "$HOME/.cargo/bin"
_prepend_path "$HOME/.local/share/pnpm"
_prepend_path "$HOME/.local/share/flutter/bin"
_prepend_path "$HOME/.pub-cache/bin"
_prepend_path "$HOME/.maestro/bin"
_prepend_path "$HOME/Android/Sdk/platform-tools"
_prepend_path "$HOME/Android/Sdk/cmdline-tools/latest/bin"
_prepend_path "$HOME/Android/Sdk/emulator"

if command -v ruby >/dev/null 2>&1; then
  _ruby_user_bin="$(ruby -e 'require "rubygems"; print Gem.user_dir' 2>/dev/null)/bin"
  _prepend_path "$_ruby_user_bin"
  unset _ruby_user_bin
fi

export EDITOR="nvim"
export VISUAL="nvim"
export TERMINAL="kitty"

# Detect an installed browser rather than hardcoding one
if [[ -z "${BROWSER:-}" ]]; then
  for _b in google-chrome-stable google-chrome chromium-browser chromium firefox brave-browser; do
    if command -v "$_b" >/dev/null 2>&1; then
      export BROWSER="$_b"
      break
    fi
  done
  unset _b
fi

export GOPATH="$HOME/go"
export CARGO_HOME="$HOME/.cargo"
export PNPM_HOME="$HOME/.local/share/pnpm"
export NPM_CONFIG_PREFIX="$HOME/.local"
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"

export HISTFILE="$HOME/.local/state/shell/history"
export HISTSIZE=100000
export SAVEHIST=100000

alias_if() {
  local name="$1"
  local command_string="$2"
  local check_bin="${3:-${command_string%% *}}"

  if command -v "$check_bin" >/dev/null 2>&1; then
    alias "$name=$command_string"
  fi
}

alias_if ls 'eza --icons=auto' eza
alias_if ll 'eza -lah --icons=auto --git' eza
alias_if la 'eza -la --icons=auto' eza
alias_if lt 'eza --tree --level=2 --icons=auto' eza
alias_if cat 'bat --style=plain' bat
alias_if grep 'rg' rg
alias c='clear'
alias v='nvim'
alias k='kubectl'
alias d='docker'
alias dc='docker compose'
alias p='podman'
alias pc='podman compose'
alias dps='docker ps'
alias pps='podman ps'
alias tf='terraform'
alias kctx='kubectl config current-context'
alias kns='kubectl config set-context --current --namespace'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
alias kaf='kubectl apply -f'
alias kdf='kubectl delete -f'
alias kl='kubectl logs -f'
alias tfa='terraform apply'
alias tfp='terraform plan'
alias tfi='terraform init'
alias tfv='terraform validate'
alias dcu='docker compose up'
alias dcud='docker compose up -d'
alias dcd='docker compose down'
alias dcl='docker compose logs -f'
alias ta='tmux attach -t'
alias tls='tmux ls'
alias tk='tmux kill-session -t'
alias tn='tmux new-session -A -s main'
alias tat='tmux attach || tmux new -s main'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias_if lg 'lazygit' lazygit
alias_if ff 'fastfetch' fastfetch

mkcd() {
  mkdir -p "$1" && cd "$1"
}

devserver() {
  python3 -m http.server "${1:-8000}"
}

kubeconfig() {
  export KUBECONFIG="$1"
  printf 'KUBECONFIG=%s\n' "$KUBECONFIG"
}

dockerctx() {
  export DOCKER_HOST=unix:///var/run/docker.sock
  printf 'Docker context active: %s\n' "$DOCKER_HOST"
}

podmanctx() {
  export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/podman/podman.sock"
  printf 'Podman context active: %s\n' "$DOCKER_HOST"
}

unsetcontainerctx() {
  unset DOCKER_HOST
  printf 'Container context cleared\n'
}

export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS='--height=45% --layout=reverse --border=rounded --preview-window=right,60%,border-left --bind=ctrl-/:toggle-preview'
export FZF_CTRL_T_OPTS='--preview "bat --style=plain --color=always --line-range=:200 {}"'
export FZF_ALT_C_OPTS='--preview "eza --tree --level=2 --icons=auto --color=always {} | head -200"'

# Create shell state dir once — skip if already present
[[ -d "$HOME/.local/state/shell" ]] || mkdir -p "$HOME/.local/state/shell"

if command -v starship >/dev/null 2>&1; then
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    eval "$(starship init zsh)"
  elif [[ -n "${BASH_VERSION:-}" ]]; then
    eval "$(starship init bash)"
  fi
fi

if [[ -f "$HOME/.atuin/bin/env" ]]; then
  . "$HOME/.atuin/bin/env"
fi
