source "$HOME/.config/dev-setup/shell-common.sh"

autoload -Uz compinit
compinit

autoload -Uz colors && colors
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zmodload zsh/complist

setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt HIST_FIND_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt INTERACTIVE_COMMENTS
setopt NO_BEEP

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init zsh --disable-up-arrow)"
fi

if command -v fzf >/dev/null 2>&1; then
  source /usr/share/fzf/key-bindings.zsh 2>/dev/null || true
  source /usr/share/fzf/completion.zsh 2>/dev/null || true
fi

if [[ -f "$HOME/.config/zsh/plugins/fzf-tab/fzf-tab.plugin.zsh" ]]; then
  source "$HOME/.config/zsh/plugins/fzf-tab/fzf-tab.plugin.zsh"
fi

if command -v dircolors >/dev/null 2>&1; then
  eval "$(dircolors -b)"
fi

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' completer _extensions _complete _approximate
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*' special-dirs true
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --tree --level=2 --icons=auto --color=always $realpath | head -200'
zstyle ':fzf-tab:*' switch-group ',' '.'
zstyle ':fzf-tab:complete:*:*' fzf-preview 'bat --style=plain --color=always --line-range=:200 $realpath 2>/dev/null || eza --tree --level=2 --icons=auto --color=always $realpath 2>/dev/null | head -200'

bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[OB' down-line-or-beginning-search
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char

[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
