#!/usr/bin/env bash

detect_distro() {
  local os_release_file="${1:-/etc/os-release}"
  if [[ -r "$os_release_file" ]]; then
    . "$os_release_file"
    case "${ID:-}" in
      arch|fedora|ubuntu|debian)
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
      rhel|centos|almalinux|rocky)
        printf 'fedora\n'
        return 0
        ;;
    esac

    case " ${ID_LIKE:-} " in
      *" ubuntu "*)  printf 'ubuntu\n';  return 0 ;;
      *" debian "*)  printf 'debian\n';  return 0 ;;
      *" arch "*)    printf 'arch\n';    return 0 ;;
      *" suse "*)    printf 'opensuse\n'; return 0 ;;
      *" rhel "*|*" fedora "*|*" centos "*) printf 'fedora\n'; return 0 ;;
    esac
  fi

  return 1
}

package_group() {
  case "$1" in
    base)
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
zoxide
fastfetch
btop
starship
direnv
gh
python3
pipx
uv
openssh
gnupg
rsync
wl-clipboard
xclip
p7zip
xdg-utils
flatpak
font-jetbrains-mono-nerd
lazygit
kitty
alacritty
rustup
python-neovim
ruby
atuin
EOF
      ;;
    gnome)
      cat <<'EOF'
gnome-shell-extension-manager
EOF
      ;;
    web)
      cat <<'EOF'
httpie
sqlite
postgresql-client
mysql-client
redis-tools
mongosh
mkcert
EOF
      ;;
    mobile)
      cat <<'EOF'
android-tools
gradle
scrcpy
jdk21
EOF
      ;;
    devops)
      cat <<'EOF'
docker
docker-compose
docker-buildx
podman
podman-docker
buildah
skopeo
kubectl
helm
kustomize
terraform
ansible
packer
aws-cli
azure-cli
age
hadolint
EOF
      ;;
    gui)
      cat <<'EOF'
code
google-chrome
podman-desktop
jetbrains-toolbox
EOF
      ;;
    *)
      return 1
      ;;
  esac
}

package_requirement_satisfied() {
  local pkg="$1"

  case "$pkg" in
    wget|wget1-wget|wget2-wget|wget1|wget2)
      have wget
      ;;
    starship)
      have starship
      ;;
    p7zip|p7zip-full|7zip|7zip-reduced|7zip-standalone|7zip-standalone-all)
      have 7zz || have 7z
      ;;
    community-mysql|mariadb|mariadb-client|mariadb-clients|default-mysql-client)
      have mysql || have mariadb
      ;;
    redis)
      have redis-cli
      ;;
    docker-compose|docker-compose-plugin|docker-compose-switch)
      have docker-compose || docker compose version >/dev/null 2>&1
      ;;
    docker-buildx|docker-buildx-plugin)
      docker buildx version >/dev/null 2>&1
      ;;
    kubernetes-client|kubectl)
      have kubectl
      ;;
    helm)
      have helm
      ;;
    kustomize)
      have kustomize
      ;;
    terraform)
      have terraform
      ;;
    packer)
      have packer
      ;;
    *)
      return 1
      ;;
  esac
}

reconcile_packages() {
  local distro="$1"
  shift

  case "$distro" in
    fedora)
      local -a kept=()
      local pkg
      local has_docker=0

      for pkg in "$@"; do
        if [[ "$pkg" == "moby-engine" ]]; then
          has_docker=1
          break
        fi
      done

      for pkg in "$@"; do
        if [[ "$pkg" == "podman-docker" && "$has_docker" -eq 1 ]]; then
          continue
        fi
        kept+=("$pkg")
      done

      printf '%s\n' "${kept[@]}"
      ;;
    *)
      printf '%s\n' "$@"
      ;;
  esac
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
    arch:zoxide) echo zoxide ;;
    arch:fastfetch) echo fastfetch ;;
    arch:btop) echo btop ;;
    arch:starship) echo starship ;;
    arch:direnv) echo direnv ;;
    arch:gh) echo github-cli ;;
    arch:python3) echo python ;;
    arch:pipx) echo python-pipx ;;
    arch:openssh) echo openssh ;;
    arch:gnupg) echo gnupg ;;
    arch:rsync) echo rsync ;;
    arch:wl-clipboard) echo wl-clipboard ;;
    arch:xclip) echo xclip ;;
    arch:p7zip) echo p7zip ;;
    arch:xdg-utils) echo xdg-utils ;;
    arch:flatpak) echo flatpak ;;
    arch:font-jetbrains-mono-nerd) echo ttf-jetbrains-mono-nerd ;;
    arch:lazygit) echo lazygit ;;
    arch:kitty) echo kitty ;;
    arch:alacritty) echo alacritty ;;
    arch:gnome-shell-extension-manager) echo gnome-shell-extension-manager ;;
    arch:gext) return 1 ;;
    arch:rustup) echo rustup ;;
    arch:uv) echo uv ;;
    arch:python-neovim) echo python-neovim ;;
    arch:ruby) echo ruby ;;
    arch:atuin) echo atuin ;;
    arch:httpie) echo httpie ;;
    arch:sqlite) echo sqlite ;;
    arch:postgresql-client) echo postgresql-libs ;;
    arch:mysql-client) echo mariadb-clients ;;
    arch:redis-tools) echo redis ;;  # Arch ships redis as a single package; the CLI (redis-cli) is included
    arch:mongosh) return 1 ;;  # installed via vendor step (mongosh binary)
    arch:mkcert) echo mkcert ;;
    arch:android-tools) echo android-tools ;;
    arch:gradle) echo gradle ;;
    arch:scrcpy) echo scrcpy ;;
    arch:jdk21) echo jdk21-openjdk ;;
    arch:docker) echo docker ;;
    arch:docker-compose) echo docker-compose ;;
    arch:docker-buildx) echo docker-buildx ;;
    arch:podman) echo podman ;;
    arch:podman-docker) echo podman-docker ;;
    arch:buildah) echo buildah ;;
    arch:skopeo) echo skopeo ;;
    arch:kubectl) echo kubectl ;;
    arch:helm) echo helm ;;
    arch:kustomize) echo kustomize ;;
    arch:terraform) echo terraform ;;
    arch:ansible) echo ansible ;;
    arch:packer) echo packer ;;
    arch:aws-cli) echo aws-cli-v2 ;;
    arch:azure-cli) echo azure-cli ;;
    arch:age) echo age ;;
    arch:hadolint) echo hadolint ;;
    arch:code) echo code ;;
    arch:google-chrome) echo google-chrome ;;
    arch:podman-desktop) echo podman-desktop ;;
    arch:jetbrains-toolbox) return 1 ;;  # vendor managed

    fedora:bash) echo bash ;;
    fedora:zsh) echo zsh ;;
    fedora:git) echo git ;;
    fedora:neovim) echo neovim ;;
    fedora:curl) echo curl ;;
    fedora:wget) echo wget2-wget ;;
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
    fedora:zoxide) echo zoxide ;;
    fedora:fastfetch) echo fastfetch ;;
    fedora:btop) echo btop ;;
    fedora:starship) echo starship ;;
    fedora:direnv) echo direnv ;;
    fedora:gh) echo gh ;;
    fedora:python3) echo python3 ;;
    fedora:pipx) echo pipx ;;
    fedora:openssh) echo openssh-clients ;;
    fedora:gnupg) echo gnupg2 ;;
    fedora:rsync) echo rsync ;;
    fedora:wl-clipboard) echo wl-clipboard ;;
    fedora:xclip) echo xclip ;;
    fedora:p7zip) echo 7zip ;;
    fedora:xdg-utils) echo xdg-utils ;;
    fedora:flatpak) echo flatpak ;;
    fedora:font-jetbrains-mono-nerd) echo jetbrains-mono-fonts-all ;;
    fedora:lazygit) echo lazygit ;;
    fedora:kitty) echo kitty ;;
    fedora:alacritty) echo alacritty ;;
    fedora:gnome-shell-extension-manager) echo gnome-extensions-app ;;
    fedora:gext) return 1 ;;
    fedora:rustup) echo rustup ;;
    fedora:uv) echo uv ;;
    fedora:python-neovim) echo python3-neovim ;;
    fedora:ruby) echo ruby ;;
    fedora:atuin) echo atuin ;;
    fedora:httpie) echo httpie ;;
    fedora:sqlite) echo sqlite ;;
    fedora:postgresql-client) echo postgresql ;;  # fedora has no separate client package; psql is in postgresql
    fedora:mysql-client) echo mariadb ;;
    fedora:redis-tools) echo redis ;;
    fedora:mongosh) return 1 ;;  # installed via vendor step
    fedora:mkcert) return 1 ;;  # installed via vendor step
    fedora:android-tools) echo android-tools ;;
    fedora:gradle) echo gradle ;;
    fedora:scrcpy) echo scrcpy ;;
    fedora:jdk21) echo java-21-openjdk ;;
    fedora:docker) echo moby-engine ;;
    fedora:docker-compose) echo docker-compose ;;
    fedora:docker-buildx) echo docker-buildx ;;
    fedora:podman) echo podman ;;
    fedora:podman-docker) echo podman-docker ;;
    fedora:buildah) echo buildah ;;
    fedora:skopeo) echo skopeo ;;
    fedora:kubectl) echo kubernetes-client ;;
    fedora:helm) echo helm ;;
    fedora:kustomize) echo kustomize ;;
    fedora:terraform) echo terraform ;;
    fedora:ansible) echo ansible ;;
    fedora:packer) echo packer ;;
    fedora:aws-cli) echo awscli2 ;;
    fedora:azure-cli) echo azure-cli ;;
    fedora:age) echo age ;;
    fedora:hadolint) return 1 ;;  # installed via vendor step
    fedora:code) echo code ;;
    fedora:google-chrome) echo google-chrome-stable ;;
    fedora:podman-desktop) echo podman-desktop ;;
    fedora:jetbrains-toolbox) return 1 ;;  # vendor managed

    ubuntu:bash|debian:bash|pikaos:bash) echo bash ;;
    ubuntu:zsh|debian:zsh|pikaos:zsh) echo zsh ;;
    ubuntu:git|debian:git|pikaos:git) echo git ;;
    ubuntu:neovim|debian:neovim|pikaos:neovim) echo neovim ;;
    ubuntu:curl|debian:curl|pikaos:curl) echo curl ;;
    ubuntu:wget|debian:wget|pikaos:wget) echo wget ;;
    ubuntu:unzip|debian:unzip|pikaos:unzip) echo unzip ;;
    ubuntu:zip|debian:zip|pikaos:zip) echo zip ;;
    ubuntu:tar|debian:tar|pikaos:tar) echo tar ;;
    ubuntu:tmux|debian:tmux|pikaos:tmux) echo tmux ;;
    ubuntu:bat|debian:bat|pikaos:bat) echo bat ;;
    ubuntu:eza|debian:eza|pikaos:eza) echo eza ;;
    ubuntu:fd|debian:fd|pikaos:fd) echo fd-find ;;
    ubuntu:fzf|debian:fzf|pikaos:fzf) echo fzf ;;
    ubuntu:ripgrep|debian:ripgrep|pikaos:ripgrep) echo ripgrep ;;
    ubuntu:jq|debian:jq|pikaos:jq) echo jq ;;
    ubuntu:zoxide|debian:zoxide|pikaos:zoxide) echo zoxide ;;
    ubuntu:fastfetch|debian:fastfetch|pikaos:fastfetch) echo fastfetch ;;
    ubuntu:btop|debian:btop|pikaos:btop) echo btop ;;
    ubuntu:starship|debian:starship|pikaos:starship) echo starship ;;
    ubuntu:direnv|debian:direnv|pikaos:direnv) echo direnv ;;
    ubuntu:gh|debian:gh|pikaos:gh) echo gh ;;
    ubuntu:python3|debian:python3|pikaos:python3) echo python3 ;;
    ubuntu:pipx|debian:pipx|pikaos:pipx) echo pipx ;;
    ubuntu:openssh|debian:openssh|pikaos:openssh) echo openssh-client ;;
    ubuntu:gnupg|debian:gnupg|pikaos:gnupg) echo gnupg ;;
    ubuntu:rsync|debian:rsync|pikaos:rsync) echo rsync ;;
    ubuntu:wl-clipboard|debian:wl-clipboard|pikaos:wl-clipboard) echo wl-clipboard ;;
    ubuntu:xclip|debian:xclip|pikaos:xclip) echo xclip ;;
    ubuntu:p7zip|debian:p7zip|pikaos:p7zip) echo p7zip-full ;;
    ubuntu:xdg-utils|debian:xdg-utils|pikaos:xdg-utils) echo xdg-utils ;;
    ubuntu:flatpak|debian:flatpak|pikaos:flatpak) echo flatpak ;;
    ubuntu:font-jetbrains-mono-nerd|debian:font-jetbrains-mono-nerd|pikaos:font-jetbrains-mono-nerd) echo fonts-jetbrains-mono ;;
    ubuntu:lazygit|debian:lazygit|pikaos:lazygit) echo lazygit ;;
    ubuntu:kitty|debian:kitty|pikaos:kitty) echo kitty ;;
    ubuntu:alacritty|debian:alacritty|pikaos:alacritty) echo alacritty ;;
    ubuntu:gnome-shell-extension-manager|debian:gnome-shell-extension-manager|pikaos:gnome-shell-extension-manager) echo gnome-shell-extension-manager ;;
    ubuntu:gext|debian:gext|pikaos:gext) return 1 ;;
    ubuntu:rustup|debian:rustup|pikaos:rustup) return 1 ;;
    ubuntu:uv|debian:uv|pikaos:uv) return 1 ;;
    ubuntu:python-neovim|debian:python-neovim|pikaos:python-neovim) echo python3-neovim ;;
    ubuntu:ruby|debian:ruby|pikaos:ruby) echo ruby ;;
    ubuntu:atuin|debian:atuin|pikaos:atuin) echo atuin ;;
    ubuntu:httpie|debian:httpie|pikaos:httpie) echo httpie ;;
    ubuntu:sqlite|debian:sqlite|pikaos:sqlite) echo sqlite3 ;;
    ubuntu:postgresql-client|debian:postgresql-client|pikaos:postgresql-client) echo postgresql-client ;;
    ubuntu:mysql-client|debian:mysql-client|pikaos:mysql-client) echo default-mysql-client ;;
    ubuntu:redis-tools|debian:redis-tools|pikaos:redis-tools) echo redis-tools ;;
    ubuntu:mongosh|debian:mongosh|pikaos:mongosh) return 1 ;;  # installed via vendor step
    ubuntu:mkcert|debian:mkcert|pikaos:mkcert) return 1 ;;    # installed via vendor step
    ubuntu:android-tools|debian:android-tools|pikaos:android-tools) echo adb ;;
    ubuntu:gradle|debian:gradle|pikaos:gradle) echo gradle ;;
    ubuntu:scrcpy|debian:scrcpy|pikaos:scrcpy) echo scrcpy ;;
    ubuntu:jdk21|debian:jdk21|pikaos:jdk21) echo openjdk-21-jdk ;;
    ubuntu:docker|debian:docker|pikaos:docker) echo docker.io ;;
    ubuntu:docker-compose|debian:docker-compose|pikaos:docker-compose) echo docker-compose-v2 ;;
    ubuntu:docker-buildx|debian:docker-buildx|pikaos:docker-buildx) echo docker-buildx-plugin ;;
    ubuntu:podman|debian:podman|pikaos:podman) echo podman ;;
    ubuntu:podman-docker|debian:podman-docker|pikaos:podman-docker) echo podman-docker ;;
    ubuntu:buildah|debian:buildah|pikaos:buildah) echo buildah ;;
    ubuntu:skopeo|debian:skopeo|pikaos:skopeo) echo skopeo ;;
    ubuntu:kubectl|debian:kubectl|pikaos:kubectl) return 1 ;;  # Not in default apt repos
    ubuntu:helm|debian:helm|pikaos:helm) return 1 ;;  # Not in default apt repos
    ubuntu:kustomize|debian:kustomize|pikaos:kustomize) printf '[dev-setup] warning: kustomize not in apt repos; install manually or via vendor binary\n' >&2; return 1 ;;
    ubuntu:terraform|debian:terraform|pikaos:terraform) return 1 ;;  # Not in default apt repos
    ubuntu:ansible|debian:ansible|pikaos:ansible) echo ansible ;;
    ubuntu:packer|debian:packer|pikaos:packer) return 1 ;;  # Not in default apt repos
    ubuntu:aws-cli|debian:aws-cli|pikaos:aws-cli) echo awscli ;;
    ubuntu:azure-cli|debian:azure-cli|pikaos:azure-cli) return 1 ;;  # Not in default apt repos
    ubuntu:age|debian:age|pikaos:age) echo age ;;
    ubuntu:hadolint|debian:hadolint|pikaos:hadolint) return 1 ;;  # installed via vendor step
    ubuntu:code|debian:code|pikaos:code) printf '[dev-setup] warning: VS Code (code) not in apt repos; add Microsoft repo or install manually\n' >&2; return 1 ;;
    ubuntu:google-chrome|debian:google-chrome|pikaos:google-chrome) printf '[dev-setup] warning: Google Chrome not in apt repos; add Google repo or install manually\n' >&2; return 1 ;;
    ubuntu:podman-desktop|debian:podman-desktop|pikaos:podman-desktop) printf '[dev-setup] warning: Podman Desktop not in apt repos; install from https://podman-desktop.io manually\n' >&2; return 1 ;;
    ubuntu:jetbrains-toolbox|debian:jetbrains-toolbox|pikaos:jetbrains-toolbox) return 1 ;;  # vendor managed

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
    opensuse:zoxide) echo zoxide ;;
    opensuse:fastfetch) echo fastfetch ;;
    opensuse:btop) echo btop ;;
    opensuse:starship) echo starship ;;
    opensuse:direnv) echo direnv ;;
    opensuse:gh) echo gh ;;
    opensuse:python3) echo python3 ;;
    opensuse:pipx) echo python3-pipx ;;
    opensuse:openssh) echo openssh-clients ;;
    opensuse:gnupg) echo gpg2 ;;
    opensuse:rsync) echo rsync ;;
    opensuse:wl-clipboard) echo wl-clipboard ;;
    opensuse:xclip) echo xclip ;;
    opensuse:p7zip) echo 7zip ;;
    opensuse:xdg-utils) echo xdg-utils ;;
    opensuse:flatpak) echo flatpak ;;
    opensuse:font-jetbrains-mono-nerd) echo google-jetbrains-mono-fonts ;;
    opensuse:lazygit) echo lazygit ;;
    opensuse:kitty) echo kitty ;;
    opensuse:alacritty) echo alacritty ;;
    opensuse:gnome-shell-extension-manager) echo gnome-shell-extension-manager ;;
    opensuse:gext) return 1 ;;
    opensuse:rustup) echo rustup ;;
    opensuse:uv) return 1 ;;
    opensuse:python-neovim) echo python3-neovim ;;
    opensuse:ruby) echo ruby ;;
    opensuse:atuin) echo atuin ;;
    opensuse:httpie) echo httpie ;;
    opensuse:sqlite) echo sqlite3 ;;
    opensuse:postgresql-client) echo postgresql ;;
    opensuse:mysql-client) echo mariadb-client ;;
    opensuse:redis-tools) echo redis ;;
    opensuse:mongosh) return 1 ;;  # installed via vendor step
    opensuse:mkcert) return 1 ;;  # installed via vendor step
    opensuse:android-tools) echo android-tools ;;
    opensuse:gradle) echo gradle ;;
    opensuse:scrcpy) echo scrcpy ;;
    opensuse:jdk21) echo java-21-openjdk ;;
    opensuse:docker) echo docker ;;
    opensuse:docker-compose) echo docker-compose-switch ;;
    opensuse:docker-buildx) echo docker-buildx ;;
    opensuse:podman) echo podman ;;
    opensuse:podman-docker) echo podman-docker ;;
    opensuse:buildah) echo buildah ;;
    opensuse:skopeo) echo skopeo ;;
    opensuse:kubectl) echo kubernetes-client ;;
    opensuse:helm) echo helm ;;
    opensuse:kustomize) echo kustomize ;;
    opensuse:terraform) echo terraform ;;
    opensuse:ansible) echo ansible ;;
    opensuse:packer) echo packer ;;
    opensuse:aws-cli) echo aws-cli ;;
    opensuse:azure-cli) echo azure-cli ;;
    opensuse:age) echo age ;;
    opensuse:hadolint) return 1 ;;  # installed via vendor step
    opensuse:code) echo code ;;
    opensuse:google-chrome) echo google-chrome-stable ;;
    opensuse:podman-desktop) echo podman-desktop ;;
    opensuse:jetbrains-toolbox) return 1 ;;  # vendor managed
    *) return 1 ;;
  esac
}

resolve_packages() {
  local distro="$1"
  local group="$2"
  local pkg mapped

  while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    if mapped="$(map_package "$distro" "$pkg" 2>/dev/null)"; then
      printf '%s\n' "$mapped"
    fi
  done < <(package_group "$group")
}
