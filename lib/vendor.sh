#!/usr/bin/env bash

MISE_INSTALL_PATH="$HOME/.local/bin"
FLUTTER_ROOT="$HOME/.local/share/flutter"
ANDROID_SDK_ROOT_DEFAULT="$HOME/Android/Sdk"
ANDROID_CMDLINE_TOOLS_VERSION="11076708"

download_release_asset() {
  local url="$1"
  local output="$2"

  curl -fsSL "$url" -o "$output"
}

install_binary_from_tarball() {
  local name="$1"
  local url="$2"
  local binary_path_in_archive="$3"
  local archive="/tmp/opencode/${name}.tar.gz"
  local extract_dir="/tmp/opencode/${name}-extract"

  log "Installing $name"
  rm -rf "$extract_dir"
  mkdir -p "$HOME/.local/bin" "$extract_dir"
  download_release_asset "$url" "$archive"
  tar -xzf "$archive" -C "$extract_dir"
  install -m 0755 "$extract_dir/$binary_path_in_archive" "$HOME/.local/bin/$name"
}

install_binary_from_zip() {
  local name="$1"
  local url="$2"
  local binary_path_in_archive="$3"
  local archive="/tmp/opencode/${name}.zip"
  local extract_dir="/tmp/opencode/${name}-extract"

  log "Installing $name"
  rm -rf "$extract_dir"
  mkdir -p "$HOME/.local/bin" "$extract_dir"
  download_release_asset "$url" "$archive"
  unzip -qo "$archive" -d "$extract_dir"
  install -m 0755 "$extract_dir/$binary_path_in_archive" "$HOME/.local/bin/$name"
}

ensure_vendor_paths() {
  export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$HOME/.local/share/mise/bin:$PATH"
}

install_mise() {
  ensure_vendor_paths

  if have mise; then
    return 0
  fi

  log "Installing mise"
  mkdir -p "$MISE_INSTALL_PATH"
  curl https://mise.run | sh
  ensure_vendor_paths
}

install_mise_toolchains() {
  install_mise

  if ! have mise; then
    warn "mise not available; skipping runtime install"
    return 0
  fi

  log "Installing runtimes with mise"
  mise install node@lts python@3.12 java@temurin-21 go@latest rust@stable bun@latest deno@latest || warn "Some mise runtime installs failed"
}

install_flutter_sdk() {
  if [[ -d "$FLUTTER_ROOT/.git" ]]; then
    log "Updating Flutter SDK"
    git -C "$FLUTTER_ROOT" pull --ff-only >/dev/null 2>&1 || warn "Flutter update failed"
  else
    log "Installing Flutter SDK"
    mkdir -p "$(dirname "$FLUTTER_ROOT")"
    git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$FLUTTER_ROOT" >/dev/null 2>&1 || warn "Flutter install failed"
  fi

  if [[ -x "$FLUTTER_ROOT/bin/flutter" ]]; then
    "$FLUTTER_ROOT/bin/flutter" config --no-analytics >/dev/null 2>&1 || true
    "$FLUTTER_ROOT/bin/dart" --disable-analytics >/dev/null 2>&1 || true
  fi
}

install_android_cmdline_tools() {
  local android_home="${ANDROID_HOME:-$ANDROID_SDK_ROOT_DEFAULT}"
  local tools_root="$android_home/cmdline-tools"
  local latest_root="$tools_root/latest"
  local archive="/tmp/opencode/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}.zip"
  local sdkmanager_bin="$latest_root/bin/sdkmanager"

  mkdir -p "$tools_root"

  if [[ ! -x "$sdkmanager_bin" ]]; then
    log "Installing Android command-line tools"
    curl -L "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip" -o "$archive"
    rm -rf "$latest_root"
    unzip -qo "$archive" -d "$tools_root"
    mv "$tools_root/cmdline-tools" "$latest_root"
  fi

  if [[ -x "$sdkmanager_bin" ]]; then
    yes | "$sdkmanager_bin" --licenses >/dev/null 2>&1 || true
    "$sdkmanager_bin" --sdk_root="$android_home" \
      "platform-tools" \
      "platforms;android-35" \
      "build-tools;35.0.0" \
      "cmdline-tools;latest" \
      "emulator" >/dev/null 2>&1 || warn "Some Android SDK components failed"
  else
    warn "sdkmanager not available; skipping Android SDK components"
  fi
}

bootstrap_role_vendors() {
  case "$1" in
    web|devops)
      install_mise_toolchains
      ;;
    mobile)
      install_mise_toolchains
      install_flutter_sdk
      install_android_cmdline_tools
      ;;
  esac
}

bootstrap_optional_vendors() {
  if have flatpak; then
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || true
  fi
}

install_terragrunt() {
  have terragrunt && return 0
  install_binary_from_tarball terragrunt \
    "https://github.com/gruntwork-io/terragrunt/releases/latest/download/terragrunt_linux_amd64.tar.gz" \
    "terragrunt"
}

install_stern() {
  have stern && return 0
  install_binary_from_tarball stern \
    "https://github.com/stern/stern/releases/latest/download/stern_linux_amd64.tar.gz" \
    "stern"
}

install_trivy() {
  have trivy && return 0
  install_binary_from_tarball trivy \
    "https://github.com/aquasecurity/trivy/releases/latest/download/trivy_Linux-64bit.tar.gz" \
    "trivy"
}

install_sops() {
  have sops && return 0
  log "Installing sops"
  mkdir -p "$HOME/.local/bin"
  download_release_asset "https://github.com/getsops/sops/releases/latest/download/sops-v3.9.0.linux.amd64" "$HOME/.local/bin/sops"
  chmod 0755 "$HOME/.local/bin/sops"
}

install_cosign() {
  have cosign && return 0
  log "Installing cosign"
  mkdir -p "$HOME/.local/bin"
  download_release_asset "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64" "$HOME/.local/bin/cosign"
  chmod 0755 "$HOME/.local/bin/cosign"
}

install_kind() {
  have kind && return 0
  log "Installing kind"
  mkdir -p "$HOME/.local/bin"
  download_release_asset "https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64" "$HOME/.local/bin/kind"
  chmod 0755 "$HOME/.local/bin/kind"
}

install_k9s() {
  have k9s && return 0
  install_binary_from_tarball k9s \
    "https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz" \
    "k9s"
}

install_kubectx_tools() {
  local target_dir="$HOME/.local/share/kubectx"
  mkdir -p "$target_dir" "$HOME/.local/bin"

  if [[ ! -d "$target_dir/.git" ]]; then
    log "Installing kubectx and kubens"
    git clone --depth 1 https://github.com/ahmetb/kubectx "$target_dir" >/dev/null 2>&1 || {
      warn "kubectx install failed"
      return 0
    }
  fi

  ln -sfn "$target_dir/kubectx" "$HOME/.local/bin/kubectx"
  ln -sfn "$target_dir/kubens" "$HOME/.local/bin/kubens"
}

install_minikube() {
  have minikube && return 0
  log "Installing minikube"
  mkdir -p "$HOME/.local/bin"
  download_release_asset "https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64" "$HOME/.local/bin/minikube"
  chmod 0755 "$HOME/.local/bin/minikube"
}

install_web_vendor_tools() {
  install_mise_toolchains
}

install_mobile_vendor_tools() {
  install_mise_toolchains
  install_flutter_sdk
  install_android_cmdline_tools
}

install_devops_vendor_tools() {
  install_mise_toolchains
  install_terragrunt
  install_stern
  install_trivy
  install_sops
  install_cosign
  install_kind
  install_k9s
  install_kubectx_tools
  install_minikube
}

bootstrap_role_vendors() {
  case "$1" in
    web)
      install_web_vendor_tools
      ;;
    mobile)
      install_mobile_vendor_tools
      ;;
    devops)
      install_devops_vendor_tools
      ;;
  esac
}
