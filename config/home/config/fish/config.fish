# Fish shell configuration for dev-setup

# ── PATH helpers ─────────────────────────────────────────────────────────────
function _prepend_path
    set -l dir $argv[1]
    if not test -d $dir
        return 0
    end
    if not contains $dir $PATH
        set -gx PATH $dir $PATH
    end
end

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

if command -v ruby >/dev/null 2>&1
    set -l ruby_user_bin (ruby -e 'require "rubygems"; print Gem.user_dir' 2>/dev/null)/bin
    _prepend_path "$ruby_user_bin"
end

# ── Environment ──────────────────────────────────────────────────────────────
set -gx EDITOR "nvim"
set -gx VISUAL "nvim"
set -gx TERMINAL "kitty"

# Browser detection
if test -z "$BROWSER"
    for _b in google-chrome-stable google-chrome chromium-browser chromium firefox brave-browser
        if command -v $_b >/dev/null 2>&1
            set -gx BROWSER $_b
            break
        end
    end
end

if test -z "$CHROME_EXECUTABLE"
    if command -v google-chrome >/dev/null 2>&1
        set -gx CHROME_EXECUTABLE (command -v google-chrome)
    else if command -v google-chrome-stable >/dev/null 2>&1
        set -gx CHROME_EXECUTABLE (command -v google-chrome-stable)
    end
end

set -gx GOPATH "$HOME/go"
set -gx CARGO_HOME "$HOME/.cargo"
set -gx PNPM_HOME "$HOME/.local/share/pnpm"
set -gx NPM_CONFIG_PREFIX "$HOME/.local"
set -gx ANDROID_HOME "$HOME/Android/Sdk"
set -gx ANDROID_SDK_ROOT "$ANDROID_HOME"

set -gx HISTFILE "$HOME/.local/state/shell/history"
set -gx HISTSIZE 100000
set -gx SAVEHIST 100000

set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --exclude .git'
set -gx FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
set -gx FZF_ALT_C_COMMAND 'fd --type d --hidden --follow --exclude .git'
set -gx FZF_DEFAULT_OPTS '--height=45% --layout=reverse --border=rounded --preview-window=right,60%,border-left --bind=ctrl-/:toggle-preview'
set -gx FZF_CTRL_T_OPTS '--preview "bat --style=plain --color=always --line-range=:200 {}"'
set -gx FZF_ALT_C_OPTS '--preview "eza --tree --level=2 --icons=auto --color=always {} | head -200"'

# Ensure shell state dir exists
mkdir -p "$HOME/.local/state/shell"

# ── Tool initializations ─────────────────────────────────────────────────────
if command -v starship >/dev/null 2>&1
    starship init fish | source
end

if command -v zoxide >/dev/null 2>&1
    zoxide init fish | source
end

if command -v direnv >/dev/null 2>&1
    direnv hook fish | source
end

if command -v atuin >/dev/null 2>&1
    atuin init fish --disable-up-arrow | source
end

if command -v fzf >/dev/null 2>&1
    fzf --fish | source 2>/dev/null || true
end

# ── Aliases ──────────────────────────────────────────────────────────────────
function _alias_if
    set -l name $argv[1]
    set -l command_string $argv[2]
    set -l check_bin $argv[3]
    if test -z "$check_bin"
        set check_bin (echo $command_string | awk '{print $1}')
    end
    if command -v $check_bin >/dev/null 2>&1
        alias $name "$command_string"
    end
end

_alias_if ls 'eza --icons=auto' eza
_alias_if ll 'eza -lah --icons=auto --git' eza
_alias_if la 'eza -la --icons=auto' eza
_alias_if lt 'eza --tree --level=2 --icons=auto' eza
_alias_if cat 'bat --style=plain' bat
_alias_if grep 'rg' rg

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

_alias_if lg 'lazygit' lazygit
_alias_if ff 'fastfetch' fastfetch

# ── Functions ────────────────────────────────────────────────────────────────
function mkcd
    mkdir -p $argv[1] && cd $argv[1]
end

function devserver
    python3 -m http.server $argv[1]
end

function kubeconfig
    set -gx KUBECONFIG $argv[1]
    printf 'KUBECONFIG=%s\n' "$KUBECONFIG"
end

function dockerctx
    set -gx DOCKER_HOST unix:///var/run/docker.sock
    printf 'Docker context active: %s\n' "$DOCKER_HOST"
end

function podmanctx
    set -gx DOCKER_HOST "unix://$XDG_RUNTIME_DIR/podman/podman.sock"
    printf 'Podman context active: %s\n' "$DOCKER_HOST"
end

function unsetcontainerctx
    set -e DOCKER_HOST
    printf 'Container context cleared\n'
end

# ── Local overrides ──────────────────────────────────────────────────────────
if test -f "$HOME/.config/fish/config.fish.local"
    source "$HOME/.config/fish/config.fish.local"
end
