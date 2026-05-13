#!/usr/bin/env bash

export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$HOME/go/bin:$PATH"
export PATH="$HOME/.local/share/mise/shims:$HOME/.local/share/mise/bin:$PATH"

if [[ -d "$HOME/.atuin/bin" ]]; then
  export PATH="$HOME/.atuin/bin:$PATH"
fi

export EDITOR="nvim"
export VISUAL="nvim"
export TERMINAL="kitty"
export BROWSER="google-chrome-stable"

export GOPATH="$HOME/go"
export CARGO_HOME="$HOME/.cargo"
export PNPM_HOME="$HOME/.local/share/pnpm"
export NPM_CONFIG_PREFIX="$HOME/.local"
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$PNPM_HOME:$CARGO_HOME/bin:$HOME/.local/bin:$HOME/.local/share/flutter/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/emulator:$PATH"

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

mkdir -p "$HOME/.local/state/shell"

if command -v starship >/dev/null 2>&1; then
  case "${ZSH_VERSION:-}${BASH_VERSION:-}" in
    *zsh*) eval "$(starship init zsh)" ;;
  esac
fi

if [[ -f "$HOME/.atuin/bin/env" ]]; then
  . "$HOME/.atuin/bin/env"
fi
