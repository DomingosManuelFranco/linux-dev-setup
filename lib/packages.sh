#!/usr/bin/env bash

detect_distro() {
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    case "${ID:-}" in
      arch|fedora|ubuntu)
        printf '%s\n' "$ID"
        return 0
        ;;
      opensuse-tumbleweed|opensuse-leap|opensuse)
        printf 'opensuse\n'
        return 0
        ;;
      pikaos)
        printf 'pikaos\n'
        return 0
        ;;
    esac

    case " ${ID_LIKE:-} " in
      *" ubuntu "*) printf 'ubuntu\n'; return 0 ;;
      *" arch "*) printf 'arch\n'; return 0 ;;
      *" suse "*) printf 'opensuse\n'; return 0 ;;
    esac
  fi

  return 1
}

base_packages() {
  cat <<'EOF'
bash
zsh
git
neovim
curl
wget
unzip
zip
tar
tmux
bat
eza
fd
fzf
ripgrep
jq
yq
zoxide
fastfetch
btop
starship
direnv
gh
nodejs
npm
pnpm
uv
pipx
python3
go
rustup
jdk17
kitty
alacritty
flatpak
xdg-utils
font-jetbrains-mono-nerd
android-tools
lazygit
EOF
}

optional_packages() {
  cat <<'EOF'
docker
docker-compose
podman
podman-docker
kubectl
k9s
helm
terraform
aws-cli
azure-cli
bun
deno
code
google-chrome
google-cloud-cli
podman-desktop
EOF
}

map_package() {
  local distro="$1"
  local pkg="$2"

  case "$distro:$pkg" in
    arch:bash) echo bash ;;
    arch:zsh) echo zsh ;;
    arch:git) echo git ;;
    arch:neovim) echo neovim ;;
    arch:curl) echo curl ;;
    arch:wget) echo wget ;;
    arch:unzip) echo unzip ;;
    arch:zip) echo zip ;;
    arch:tar) echo tar ;;
    arch:tmux) echo tmux ;;
    arch:bat) echo bat ;;
    arch:eza) echo eza ;;
    arch:fd) echo fd ;;
    arch:fzf) echo fzf ;;
    arch:ripgrep) echo ripgrep ;;
    arch:jq) echo jq ;;
    arch:yq) echo yq ;;
    arch:zoxide) echo zoxide ;;
    arch:fastfetch) echo fastfetch ;;
    arch:btop) echo btop ;;
    arch:starship) echo starship ;;
    arch:direnv) echo direnv ;;
    arch:gh) echo github-cli ;;
    arch:docker) echo docker ;;
    arch:docker-compose) echo docker-compose ;;
    arch:podman) echo podman ;;
    arch:podman-docker) echo podman-docker ;;
    arch:kubectl) echo kubectl ;;
    arch:k9s) echo k9s ;;
    arch:helm) echo helm ;;
    arch:terraform) echo terraform ;;
    arch:aws-cli) echo aws-cli-v2 ;;
    arch:azure-cli) echo azure-cli ;;
    arch:nodejs) echo nodejs-lts-jod ;;
    arch:npm) echo npm ;;
    arch:pnpm) echo pnpm ;;
    arch:bun) echo bun ;;
    arch:deno) echo deno ;;
    arch:uv) echo uv ;;
    arch:pipx) echo python-pipx ;;
    arch:python3) echo python ;;
    arch:go) echo go ;;
    arch:rustup) echo rustup ;;
    arch:jdk17) echo jdk17-openjdk ;;
    arch:android-tools) echo android-tools ;;
    arch:kitty) echo kitty ;;
    arch:alacritty) echo alacritty ;;
    arch:flatpak) echo flatpak ;;
    arch:xdg-utils) echo xdg-utils ;;
    arch:font-jetbrains-mono-nerd) echo ttf-jetbrains-mono-nerd ;;
    arch:lazygit) echo lazygit ;;
    arch:code) echo code ;;
    arch:google-chrome) echo google-chrome ;;
    arch:google-cloud-cli) echo google-cloud-cli ;;
    arch:podman-desktop) echo podman-desktop ;;

    fedora:bash) echo bash ;;
    fedora:zsh) echo zsh ;;
    fedora:git) echo git ;;
    fedora:neovim) echo neovim ;;
    fedora:curl) echo curl ;;
    fedora:wget) echo wget ;;
    fedora:unzip) echo unzip ;;
    fedora:zip) echo zip ;;
    fedora:tar) echo tar ;;
    fedora:tmux) echo tmux ;;
    fedora:bat) echo bat ;;
    fedora:eza) echo eza ;;
    fedora:fd) echo fd-find ;;
    fedora:fzf) echo fzf ;;
    fedora:ripgrep) echo ripgrep ;;
    fedora:jq) echo jq ;;
    fedora:yq) echo yq ;;
    fedora:zoxide) echo zoxide ;;
    fedora:fastfetch) echo fastfetch ;;
    fedora:btop) echo btop ;;
    fedora:starship) echo starship ;;
    fedora:direnv) echo direnv ;;
    fedora:gh) echo gh ;;
    fedora:docker) echo moby-engine ;;
    fedora:docker-compose) echo docker-compose ;;
    fedora:podman) echo podman ;;
    fedora:podman-docker) echo podman-docker ;;
    fedora:kubectl) echo kubernetes-client ;;
    fedora:k9s) echo k9s ;;
    fedora:helm) echo helm ;;
    fedora:terraform) echo terraform ;;
    fedora:aws-cli) echo awscli2 ;;
    fedora:azure-cli) echo azure-cli ;;
    fedora:nodejs) echo nodejs ;;
    fedora:npm) echo npm ;;
    fedora:pnpm) echo pnpm ;;
    fedora:bun) echo bun ;;
    fedora:deno) echo deno ;;
    fedora:uv) echo uv ;;
    fedora:pipx) echo pipx ;;
    fedora:python3) echo python3 ;;
    fedora:go) echo golang ;;
    fedora:rustup) echo rustup ;;
    fedora:jdk17) echo java-17-openjdk ;;
    fedora:android-tools) echo android-tools ;;
    fedora:kitty) echo kitty ;;
    fedora:alacritty) echo alacritty ;;
    fedora:flatpak) echo flatpak ;;
    fedora:xdg-utils) echo xdg-utils ;;
    fedora:font-jetbrains-mono-nerd) echo jetbrains-mono-fonts-all ;;
    fedora:lazygit) echo lazygit ;;
    fedora:code) echo code ;;
    fedora:google-chrome) echo google-chrome-stable ;;
    fedora:google-cloud-cli) echo google-cloud-cli ;;
    fedora:podman-desktop) echo podman-desktop ;;

    ubuntu:bash|pikaos:bash) echo bash ;;
    ubuntu:zsh|pikaos:zsh) echo zsh ;;
    ubuntu:git|pikaos:git) echo git ;;
    ubuntu:neovim|pikaos:neovim) echo neovim ;;
    ubuntu:curl|pikaos:curl) echo curl ;;
    ubuntu:wget|pikaos:wget) echo wget ;;
    ubuntu:unzip|pikaos:unzip) echo unzip ;;
    ubuntu:zip|pikaos:zip) echo zip ;;
    ubuntu:tar|pikaos:tar) echo tar ;;
    ubuntu:tmux|pikaos:tmux) echo tmux ;;
    ubuntu:bat|pikaos:bat) echo bat ;;
    ubuntu:eza|pikaos:eza) echo eza ;;
    ubuntu:fd|pikaos:fd) echo fd-find ;;
    ubuntu:fzf|pikaos:fzf) echo fzf ;;
    ubuntu:ripgrep|pikaos:ripgrep) echo ripgrep ;;
    ubuntu:jq|pikaos:jq) echo jq ;;
    ubuntu:yq|pikaos:yq) echo yq ;;
    ubuntu:zoxide|pikaos:zoxide) echo zoxide ;;
    ubuntu:fastfetch|pikaos:fastfetch) echo fastfetch ;;
    ubuntu:btop|pikaos:btop) echo btop ;;
    ubuntu:starship|pikaos:starship) echo starship ;;
    ubuntu:direnv|pikaos:direnv) echo direnv ;;
    ubuntu:gh|pikaos:gh) echo gh ;;
    ubuntu:docker|pikaos:docker) echo docker.io ;;
    ubuntu:docker-compose|pikaos:docker-compose) echo docker-compose-v2 ;;
    ubuntu:podman|pikaos:podman) echo podman ;;
    ubuntu:podman-docker|pikaos:podman-docker) echo podman-docker ;;
    ubuntu:kubectl|pikaos:kubectl) echo kubectl ;;
    ubuntu:k9s|pikaos:k9s) echo k9s ;;
    ubuntu:helm|pikaos:helm) echo helm ;;
    ubuntu:terraform|pikaos:terraform) echo terraform ;;
    ubuntu:aws-cli|pikaos:aws-cli) echo awscli ;;
    ubuntu:azure-cli|pikaos:azure-cli) echo azure-cli ;;
    ubuntu:nodejs|pikaos:nodejs) echo nodejs ;;
    ubuntu:npm|pikaos:npm) echo npm ;;
    ubuntu:pnpm|pikaos:pnpm) echo pnpm ;;
    ubuntu:bun|pikaos:bun) echo bun ;;
    ubuntu:deno|pikaos:deno) echo deno ;;
    ubuntu:uv|pikaos:uv) echo uv ;;
    ubuntu:pipx|pikaos:pipx) echo pipx ;;
    ubuntu:python3|pikaos:python3) echo python3 ;;
    ubuntu:go|pikaos:go) echo golang-go ;;
    ubuntu:rustup|pikaos:rustup) echo rustup ;;
    ubuntu:jdk17|pikaos:jdk17) echo openjdk-17-jdk ;;
    ubuntu:android-tools|pikaos:android-tools) echo android-sdk-platform-tools-common ;;
    ubuntu:kitty|pikaos:kitty) echo kitty ;;
    ubuntu:alacritty|pikaos:alacritty) echo alacritty ;;
    ubuntu:flatpak|pikaos:flatpak) echo flatpak ;;
    ubuntu:xdg-utils|pikaos:xdg-utils) echo xdg-utils ;;
    ubuntu:font-jetbrains-mono-nerd|pikaos:font-jetbrains-mono-nerd) echo fonts-jetbrains-mono ;;
    ubuntu:lazygit|pikaos:lazygit) echo lazygit ;;
    ubuntu:code|pikaos:code) echo code ;;
    ubuntu:google-chrome|pikaos:google-chrome) echo google-chrome-stable ;;
    ubuntu:google-cloud-cli|pikaos:google-cloud-cli) echo google-cloud-cli ;;
    ubuntu:podman-desktop|pikaos:podman-desktop) echo podman-desktop ;;

    opensuse:bash) echo bash ;;
    opensuse:zsh) echo zsh ;;
    opensuse:git) echo git ;;
    opensuse:neovim) echo neovim ;;
    opensuse:curl) echo curl ;;
    opensuse:wget) echo wget ;;
    opensuse:unzip) echo unzip ;;
    opensuse:zip) echo zip ;;
    opensuse:tar) echo tar ;;
    opensuse:tmux) echo tmux ;;
    opensuse:bat) echo bat ;;
    opensuse:eza) echo eza ;;
    opensuse:fd) echo fd ;;
    opensuse:fzf) echo fzf ;;
    opensuse:ripgrep) echo ripgrep ;;
    opensuse:jq) echo jq ;;
    opensuse:yq) echo yq ;;
    opensuse:zoxide) echo zoxide ;;
    opensuse:fastfetch) echo fastfetch ;;
    opensuse:btop) echo btop ;;
    opensuse:starship) echo starship ;;
    opensuse:direnv) echo direnv ;;
    opensuse:gh) echo gh ;;
    opensuse:docker) echo docker ;;
    opensuse:docker-compose) echo docker-compose-switch ;;
    opensuse:podman) echo podman ;;
    opensuse:podman-docker) echo podman-docker ;;
    opensuse:kubectl) echo kubernetes-client ;;
    opensuse:k9s) echo k9s ;;
    opensuse:helm) echo helm ;;
    opensuse:terraform) echo terraform ;;
    opensuse:aws-cli) echo aws-cli ;;
    opensuse:azure-cli) echo azure-cli ;;
    opensuse:nodejs) echo nodejs20 ;;
    opensuse:npm) echo npm20 ;;
    opensuse:pnpm) echo pnpm ;;
    opensuse:bun) echo bun ;;
    opensuse:deno) echo deno ;;
    opensuse:uv) echo uv ;;
    opensuse:pipx) echo python311-pipx ;;
    opensuse:python3) echo python311 ;;
    opensuse:go) echo go ;;
    opensuse:rustup) echo rustup ;;
    opensuse:jdk17) echo java-17-openjdk ;;
    opensuse:android-tools) echo android-tools ;;
    opensuse:kitty) echo kitty ;;
    opensuse:alacritty) echo alacritty ;;
    opensuse:flatpak) echo flatpak ;;
    opensuse:xdg-utils) echo xdg-utils ;;
    opensuse:font-jetbrains-mono-nerd) echo google-jetbrains-mono-fonts ;;
    opensuse:lazygit) echo lazygit ;;
    opensuse:code) echo code ;;
    opensuse:google-chrome) echo google-chrome-stable ;;
    opensuse:google-cloud-cli) echo google-cloud-cli ;;
    opensuse:podman-desktop) echo podman-desktop ;;
    *) return 1 ;;
  esac
}

resolve_packages() {
  local distro="$1"
  local kind="$2"
  local pkg mapped

  local items
  if [[ "$kind" == "base" ]]; then
    items="$(base_packages)"
  else
    items="$(optional_packages)"
  fi

  while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    if mapped="$(map_package "$distro" "$pkg" 2>/dev/null)"; then
      printf '%s\n' "$mapped"
    fi
  done <<< "$items"
}
