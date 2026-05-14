#!/usr/bin/env bash

MISE_INSTALL_PATH="$HOME/.local/bin"
FLUTTER_ROOT="$HOME/.local/share/flutter"
ANDROID_SDK_ROOT_DEFAULT="$HOME/Android/Sdk"
VENDOR_TMP_DIR="${TMPDIR:-/tmp}/dev-setup-vendor"

# Detect CPU architecture and map to common naming conventions used by release assets
_arch_uname() {
  case "$(uname -m)" in
    x86_64)  printf 'x86_64' ;;
    aarch64|arm64) printf 'aarch64' ;;
    armv7l)  printf 'armv7' ;;
    *)       printf '%s' "$(uname -m)" ;;
  esac
}

# Map uname -m to the 'amd64/arm64' style used by most Go-released binaries
_arch_go() {
  case "$(uname -m)" in
    x86_64)  printf 'amd64' ;;
    aarch64|arm64) printf 'arm64' ;;
    armv7l)  printf 'arm' ;;
    *)       printf '%s' "$(uname -m)" ;;
  esac
}

# Use jq to extract a field from JSON if available, else fall back to grep+cut
_json_field() {
  local field="$1"
  local json="$2"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$json" | jq -r ".$field // empty"
  else
    printf '%s' "$json" | grep "\"${field}\"" | head -1 | cut -d'"' -f4
  fi
}

# Resolve the latest GitHub release tag for a given repo (owner/repo)
_github_latest_tag() {
  local repo="$1"
  local json
  json="$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest")"
  local tag
  tag="$(_json_field tag_name "$json")"
  printf '%s' "${tag#v}"   # strip leading 'v'
}

download_release_asset() {
  local url="$1"
  local output="$2"

  curl -fsSL "$url" -o "$output"
}

install_binary_from_tarball() {
  local name="$1"
  local url="$2"
  local binary_path_in_archive="$3"
  local archive="$VENDOR_TMP_DIR/${name}.tar.gz"
  local extract_dir="$VENDOR_TMP_DIR/${name}-extract"

  log "Installing $name"
  rm -rf "$extract_dir"
  mkdir -p "$HOME/.local/bin" "$extract_dir" "$VENDOR_TMP_DIR"
  download_release_asset "$url" "$archive"
  tar -xzf "$archive" -C "$extract_dir"
  install -m 0755 "$extract_dir/$binary_path_in_archive" "$HOME/.local/bin/$name"
  rm -f "$archive"
}

install_binary_from_bz2() {
  local name="$1"
  local url="$2"
  local binary_path_in_archive="$3"
  local archive="$VENDOR_TMP_DIR/${name}.tar.bz2"
  local extract_dir="$VENDOR_TMP_DIR/${name}-extract"

  log "Installing $name"
  rm -rf "$extract_dir"
  mkdir -p "$HOME/.local/bin" "$extract_dir" "$VENDOR_TMP_DIR"
  download_release_asset "$url" "$archive"
  tar -xjf "$archive" -C "$extract_dir"
  local bin
  bin="$(find "$extract_dir" -name "$name" -type f | head -1)"
  if [[ -n "$bin" ]]; then
    install -m 0755 "$bin" "$HOME/.local/bin/$name"
  else
    install -m 0755 "$extract_dir/$binary_path_in_archive" "$HOME/.local/bin/$name"
  fi
  rm -f "$archive"
}

install_binary_from_zip() {
  local name="$1"
  local url="$2"
  local binary_path_in_archive="$3"
  local archive="$VENDOR_TMP_DIR/${name}.zip"
  local extract_dir="$VENDOR_TMP_DIR/${name}-extract"

  log "Installing $name"
  rm -rf "$extract_dir"
  mkdir -p "$HOME/.local/bin" "$extract_dir" "$VENDOR_TMP_DIR"
  download_release_asset "$url" "$archive"
  unzip -qo "$archive" -d "$extract_dir"
  install -m 0755 "$extract_dir/$binary_path_in_archive" "$HOME/.local/bin/$name"
  rm -f "$archive"
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
  curl -fsSL https://mise.run | sh
  ensure_vendor_paths
}

install_mise_toolchains() {
  install_mise

  if ! have mise; then
    warn "mise not available; skipping runtime install"
    return 0
  fi

  # Single source of truth: read versions from config.toml if it exists
  local mise_config="$HOME/.config/mise/config.toml"
  if [[ -f "$mise_config" ]]; then
    log "Installing runtimes with mise (from config.toml)"
    mise install || warn "Some mise runtime installs failed"
  else
    log "Installing runtimes with mise (defaults)"
    mise install node@lts python@3.12 java@temurin-21 go@1.22 rust@stable bun@latest deno@latest \
      || warn "Some mise runtime installs failed"
  fi
}

install_yq() {
  have yq && return 0
  local arch
  arch="$(_arch_go)"
  log "Installing yq (mikefarah/yq)"
  mkdir -p "$HOME/.local/bin"
  download_release_asset \
    "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${arch}" \
    "$HOME/.local/bin/yq"
  chmod 0755 "$HOME/.local/bin/yq"
}

install_flutter_sdk() {
  if [[ -d "$FLUTTER_ROOT/.git" ]]; then
    log "Updating Flutter SDK"
    git -C "$FLUTTER_ROOT" fetch --depth 1 origin stable >/dev/null 2>&1 || warn "Flutter fetch failed"
    git -C "$FLUTTER_ROOT" reset --hard origin/stable >/dev/null 2>&1 || warn "Flutter update failed"
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
  local sdkmanager_bin="$latest_root/bin/sdkmanager"

  if [[ ! -e /dev/kvm ]]; then
    record_warning "KVM (/dev/kvm) not available — Android emulator hardware acceleration disabled."
  else
    log "KVM available — Android emulator hardware acceleration enabled"
  fi

  mkdir -p "$tools_root"

  if [[ ! -x "$sdkmanager_bin" ]]; then
    log "Installing Android command-line tools..."
    local resolved_version="11076708"
    local archive="$VENDOR_TMP_DIR/commandlinetools-linux-${resolved_version}.zip"
    curl -fsSL "https://dl.google.com/android/repository/commandlinetools-linux-${resolved_version}_latest.zip" -o "$archive"
    rm -rf "$latest_root"
    unzip -qo "$archive" -d "$tools_root"
    mv "$tools_root/cmdline-tools" "$latest_root"
    rm -f "$archive"
  fi

  if [[ -x "$sdkmanager_bin" ]]; then
    yes | "$sdkmanager_bin" --licenses >/dev/null 2>&1 || true
    
    local platforms
    platforms="$("$sdkmanager_bin" --sdk_root="$android_home" --list 2>/dev/null | grep -oP '^  platforms;android-\K[0-9]+' | sort -rn || true)"
    local latest_platform="$(echo "$platforms" | head -1)"
    latest_platform="${latest_platform:-35}"
    
    local build_tools
    build_tools="$("$sdkmanager_bin" --sdk_root="$android_home" --list 2>/dev/null | grep -oP '^  build-tools;\K[0-9]+\.[0-9]+\.[0-9]+' | sort -rV || true)"
    local latest_build_tools="$(echo "$build_tools" | head -1)"
    latest_build_tools="${latest_build_tools:-35.0.0}"
    
    if ! "$sdkmanager_bin" --sdk_root="$android_home" \
      "platform-tools" \
      "platforms;android-${latest_platform}" \
      "build-tools;${latest_build_tools}" \
      "cmdline-tools;latest" \
      "emulator" >/dev/null 2>&1; then
      record_vendor_failure "android-sdk-components"
    fi
  else
    record_vendor_failure "android-sdkmanager"
  fi
}

bootstrap_optional_vendors() {
  install_jetbrains_toolbox

  if have flatpak; then
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || true
  fi

  # gext is installed later (after pipx ensurepath) in install.sh
}

install_terragrunt() {
  have terragrunt && return 0
  local arch; arch="$(_arch_go)"
  install_binary_from_tarball terragrunt \
    "https://github.com/gruntwork-io/terragrunt/releases/latest/download/terragrunt_linux_${arch}.tar.gz" \
    "terragrunt"
}

install_stern() {
  have stern && return 0
  local arch; arch="$(_arch_go)"
  install_binary_from_tarball stern \
    "https://github.com/stern/stern/releases/latest/download/stern_linux_${arch}.tar.gz" \
    "stern"
}

install_trivy() {
  have trivy && return 0
  local arch_uname; arch_uname="$(_arch_uname)"
  # trivy uses 64bit / ARM64 naming
  local trivy_arch
  case "$(uname -m)" in
    x86_64)  trivy_arch="64bit" ;;
    aarch64|arm64) trivy_arch="ARM64" ;;
    *) trivy_arch="64bit" ;;
  esac
  local archive="$VENDOR_TMP_DIR/trivy.tar.gz"
  local extract_dir="$VENDOR_TMP_DIR/trivy-extract"
  log "Installing trivy"
  rm -rf "$extract_dir"
  mkdir -p "$HOME/.local/bin" "$extract_dir" "$VENDOR_TMP_DIR"
  download_release_asset "https://github.com/aquasecurity/trivy/releases/latest/download/trivy_Linux-${trivy_arch}.tar.gz" "$archive"
  tar -xzf "$archive" -C "$extract_dir"
  local trivy_bin
  trivy_bin="$(find "$extract_dir" -maxdepth 2 -name 'trivy' -type f | head -1)"
  if [[ -z "$trivy_bin" ]]; then
    warn "trivy binary not found in archive"
    rm -f "$archive"
    return 1
  fi
  install -m 0755 "$trivy_bin" "$HOME/.local/bin/trivy"
  rm -f "$archive"
}

install_sops() {
  have sops && return 0
  local arch; arch="$(_arch_go)"
  log "Installing sops"
  mkdir -p "$HOME/.local/bin"
  local latest_url
  latest_url="$(curl -fsSL -o /dev/null -w '%{url_effective}' "https://github.com/getsops/sops/releases/latest")"
  local version="${latest_url##*/}"
  download_release_asset "https://github.com/getsops/sops/releases/download/${version}/sops-${version}.linux.${arch}" "$HOME/.local/bin/sops"
  chmod 0755 "$HOME/.local/bin/sops"
}

install_cosign() {
  have cosign && return 0
  local arch; arch="$(_arch_go)"
  log "Installing cosign"
  mkdir -p "$HOME/.local/bin"
  download_release_asset "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-${arch}" "$HOME/.local/bin/cosign"
  chmod 0755 "$HOME/.local/bin/cosign"
}

install_kind() {
  have kind && return 0
  local arch; arch="$(_arch_go)"
  log "Installing kind"
  mkdir -p "$HOME/.local/bin"
  download_release_asset "https://kind.sigs.k8s.io/dl/latest/kind-linux-${arch}" "$HOME/.local/bin/kind"
  chmod 0755 "$HOME/.local/bin/kind"
}

install_k9s() {
  have k9s && return 0
  local arch; arch="$(_arch_go)"
  # k9s uses amd64/arm64 but capitalises: Linux_amd64
  install_binary_from_tarball k9s \
    "https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_${arch}.tar.gz" \
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
  local arch; arch="$(_arch_go)"
  log "Installing minikube"
  mkdir -p "$HOME/.local/bin"
  download_release_asset "https://storage.googleapis.com/minikube/releases/latest/minikube-linux-${arch}" "$HOME/.local/bin/minikube"
  chmod 0755 "$HOME/.local/bin/minikube"
}

install_web_vendor_tools() {
  install_mise_toolchains
  install_uv_if_missing
  install_rustup_if_missing
  install_fzf_tab
  install_mkcert
  install_mongosh
  install_usql
  install_yq
}

install_uv_if_missing() {
  have uv && return 0
  log "Installing uv"
  curl -fsSL https://astral.sh/uv/install.sh | sh >/dev/null 2>&1 || warn "uv install failed"
}

install_rustup_if_missing() {
  have rustup && return 0
  log "Installing rustup"
  curl -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path >/dev/null 2>&1 || warn "rustup install failed"
}

install_mobile_vendor_tools() {
  install_mise_toolchains
  install_uv_if_missing
  install_rustup_if_missing
  install_fzf_tab
  install_flutter_sdk
  install_android_cmdline_tools
  install_maestro
  install_bundletool
  install_flutter_distributor
}

install_devops_vendor_tools() {
  install_mise_toolchains
  install_uv_if_missing
  install_rustup_if_missing
  install_fzf_tab
  install_terragrunt
  install_stern
  install_trivy
  install_sops
  install_cosign
  install_kind
  install_k9s
  install_kubectx_tools
  install_minikube
  install_google_cloud_cli
  install_argocd
  install_flux
  install_gitleaks
  install_trufflehog
  install_tflint
  install_dive
  install_hadolint
  install_act
  install_kubeseal
  install_skaffold
  install_syft
  install_vault
  install_eksctl
  install_flyctl
}

install_google_cloud_cli() {
  have gcloud && return 0
  local arch_uname; arch_uname="$(_arch_uname)"
  # gcloud uses x86_64 / arm naming
  local gcloud_arch
  case "$(uname -m)" in
    x86_64)  gcloud_arch="x86_64" ;;
    aarch64|arm64) gcloud_arch="arm" ;;
    *) gcloud_arch="x86_64" ;;
  esac
  log "Installing Google Cloud CLI"
  local archive="$VENDOR_TMP_DIR/google-cloud-cli.tar.gz"
  local install_dir="$HOME/.local/share/google-cloud-sdk"
  mkdir -p "$VENDOR_TMP_DIR"
  download_release_asset \
    "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-${gcloud_arch}.tar.gz" \
    "$archive"
  rm -rf "$install_dir"
  tar -xzf "$archive" -C "$HOME/.local/share"
  # The tarball extracts to 'google-cloud-sdk'; rename if needed
  if [[ -d "$HOME/.local/share/google-cloud-sdk" && "$HOME/.local/share/google-cloud-sdk" != "$install_dir" ]]; then
    mv "$HOME/.local/share/google-cloud-sdk" "$install_dir"
  fi
  rm -f "$archive"
  "$install_dir/install.sh" --quiet --path-update=false --bash-completion=false >/dev/null 2>&1 || warn "gcloud install script failed"
  ln -sfn "$install_dir/bin/gcloud" "$HOME/.local/bin/gcloud"
  ln -sfn "$install_dir/bin/gsutil" "$HOME/.local/bin/gsutil"
  ln -sfn "$install_dir/bin/bq" "$HOME/.local/bin/bq"
}

# --- Mobile vendor tools ---

install_maestro() {
  have maestro && return 0
  log "Installing Maestro (mobile UI testing)"
  curl -fsSL "https://get.maestro.mobile.dev" | bash >/dev/null 2>&1 || warn "Maestro install failed"
}

install_bundletool() {
  have bundletool && return 0
  log "Installing bundletool"
  mkdir -p "$HOME/.local/bin" "$HOME/.local/share" "$VENDOR_TMP_DIR"
  download_release_asset \
    "https://github.com/google/bundletool/releases/latest/download/bundletool-all.jar" \
    "$HOME/.local/share/bundletool.jar"
  cat > "$HOME/.local/bin/bundletool" <<'SCRIPT'
#!/usr/bin/env sh
exec java -jar "$HOME/.local/share/bundletool.jar" "$@"
SCRIPT
  chmod 0755 "$HOME/.local/bin/bundletool"
}

install_flutter_distributor() {
  have flutter_distributor && return 0
  if have flutter; then
    log "Installing flutter_distributor"
    dart pub global activate flutter_distributor >/dev/null 2>&1 || warn "flutter_distributor install failed"
  else
    warn "flutter not found; skipping flutter_distributor"
  fi
}

# --- Web vendor tools ---

install_mkcert() {
  have mkcert && return 0
  local arch; arch="$(_arch_go)"
  log "Installing mkcert"
  mkdir -p "$HOME/.local/bin"
  local version
  version="$(_github_latest_tag FiloSottile/mkcert)"
  if [[ -z "$version" ]]; then
    warn "Could not resolve mkcert version; skipping"
    return 1
  fi
  download_release_asset \
    "https://github.com/FiloSottile/mkcert/releases/latest/download/mkcert-v${version}-linux-${arch}" \
    "$HOME/.local/bin/mkcert"
  chmod 0755 "$HOME/.local/bin/mkcert"
}

install_mongosh() {
  have mongosh && return 0
  local arch; arch="$(_arch_go)"
  # mongosh uses x64/arm64 naming
  local mongosh_arch
  case "$(uname -m)" in
    x86_64) mongosh_arch="x64" ;;
    *) mongosh_arch="$arch" ;;
  esac
  log "Installing mongosh"
  local extract_dir="$VENDOR_TMP_DIR/mongosh-extract"
  local archive="$VENDOR_TMP_DIR/mongosh.tgz"
  rm -rf "$extract_dir"
  mkdir -p "$extract_dir" "$VENDOR_TMP_DIR" "$HOME/.local/bin"
  local version
  version="$(_github_latest_tag mongodb-js/mongosh)"
  if [[ -z "$version" ]]; then
    warn "Could not resolve mongosh version; skipping"
    return 1
  fi
  download_release_asset \
    "https://github.com/mongodb-js/mongosh/releases/download/v${version}/mongosh-${version}-linux-${mongosh_arch}.tgz" \
    "$archive"
  tar -xzf "$archive" -C "$extract_dir"
  local bin
  bin="$(find "$extract_dir" -name 'mongosh' -type f | head -1)"
  if [[ -n "$bin" ]]; then
    install -m 0755 "$bin" "$HOME/.local/bin/mongosh"
  else
    warn "mongosh binary not found in archive"
  fi
  rm -f "$archive"
}

install_usql() {
  have usql && return 0
  local arch; arch="$(_arch_go)"
  install_binary_from_bz2 usql \
    "https://github.com/xo/usql/releases/latest/download/usql-linux-${arch}.tar.bz2" \
    "usql"
}

# --- DevOps vendor tools ---

install_argocd() {
  have argocd && return 0
  local arch; arch="$(_arch_go)"
  log "Installing argocd"
  mkdir -p "$HOME/.local/bin"
  download_release_asset \
    "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-${arch}" \
    "$HOME/.local/bin/argocd"
  chmod 0755 "$HOME/.local/bin/argocd"
}

install_flux() {
  have flux && return 0
  log "Installing flux"
  curl -fsSL https://fluxcd.io/install.sh | FLUX_VERSION=latest bash -s -- --bin-dir "$HOME/.local/bin" >/dev/null 2>&1 || warn "flux install failed"
}

install_gitleaks() {
  have gitleaks && return 0
  local arch; arch="$(_arch_go)"
  # gitleaks uses x64/arm64
  local gitleaks_arch
  case "$(uname -m)" in
    x86_64) gitleaks_arch="x64" ;;
    *) gitleaks_arch="$arch" ;;
  esac
  local version
  version="$(_github_latest_tag gitleaks/gitleaks)"
  if [[ -z "$version" ]]; then
    warn "Could not resolve gitleaks version; skipping"
    return 1
  fi
  install_binary_from_tarball gitleaks \
    "https://github.com/gitleaks/gitleaks/releases/latest/download/gitleaks_${version}_linux_${gitleaks_arch}.tar.gz" \
    "gitleaks"
}

install_trufflehog() {
  have trufflehog && return 0
  local arch; arch="$(_arch_go)"
  install_binary_from_tarball trufflehog \
    "https://github.com/trufflesecurity/trufflehog/releases/latest/download/trufflehog_linux_${arch}.tar.gz" \
    "trufflehog"
}

install_tflint() {
  have tflint && return 0
  local arch; arch="$(_arch_go)"
  install_binary_from_zip tflint \
    "https://github.com/terraform-linters/tflint/releases/latest/download/tflint_linux_${arch}.zip" \
    "tflint"
}

install_dive() {
  have dive && return 0
  local arch; arch="$(_arch_go)"
  install_binary_from_tarball dive \
    "https://github.com/wagoodman/dive/releases/latest/download/dive_linux_${arch}.tar.gz" \
    "dive"
}

install_hadolint() {
  have hadolint && return 0
  local arch; arch="$(_arch_uname)"
  log "Installing hadolint"
  mkdir -p "$HOME/.local/bin"
  download_release_asset \
    "https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-${arch}" \
    "$HOME/.local/bin/hadolint"
  chmod 0755 "$HOME/.local/bin/hadolint"
}

install_act() {
  have act && return 0
  local arch; arch="$(_arch_uname)"
  install_binary_from_tarball act \
    "https://github.com/nektos/act/releases/latest/download/act_Linux_${arch}.tar.gz" \
    "act"
}

install_kubeseal() {
  have kubeseal && return 0
  local arch; arch="$(_arch_go)"
  install_binary_from_tarball kubeseal \
    "https://github.com/bitnami-labs/sealed-secrets/releases/latest/download/kubeseal-linux-${arch}.tar.gz" \
    "kubeseal"
}

install_skaffold() {
  have skaffold && return 0
  local arch; arch="$(_arch_go)"
  log "Installing skaffold"
  mkdir -p "$HOME/.local/bin"
  download_release_asset \
    "https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-${arch}" \
    "$HOME/.local/bin/skaffold"
  chmod 0755 "$HOME/.local/bin/skaffold"
}

install_syft() {
  have syft && return 0
  log "Installing syft"
  curl -fsSL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b "$HOME/.local/bin" >/dev/null 2>&1 || warn "syft install failed"
}

install_vault() {
  have vault && return 0
  local arch; arch="$(_arch_go)"
  log "Installing vault"
  local extract_dir="$VENDOR_TMP_DIR/vault-extract"
  local archive="$VENDOR_TMP_DIR/vault.zip"
  local version
  version="$(_github_latest_tag hashicorp/vault)"
  if [[ -z "$version" ]]; then
    warn "Could not resolve vault version; skipping"
    return 1
  fi
  rm -rf "$extract_dir"
  mkdir -p "$extract_dir" "$VENDOR_TMP_DIR" "$HOME/.local/bin"
  download_release_asset \
    "https://releases.hashicorp.com/vault/${version}/vault_${version}_linux_${arch}.zip" \
    "$archive"
  unzip -qo "$archive" -d "$extract_dir"
  install -m 0755 "$extract_dir/vault" "$HOME/.local/bin/vault"
  rm -f "$archive"
}

install_eksctl() {
  have eksctl && return 0
  local arch; arch="$(_arch_uname)"
  install_binary_from_tarball eksctl \
    "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_${arch}.tar.gz" \
    "eksctl"
}

install_flyctl() {
  have flyctl && return 0
  log "Installing flyctl"
  curl -fsSL https://fly.io/install.sh | FLYCTL_INSTALL="$HOME/.local" sh >/dev/null 2>&1 || warn "flyctl install failed"
}

install_fzf_tab() {
  local plugin_dir="$HOME/.config/zsh/plugins/fzf-tab"
  if [[ -d "$plugin_dir/.git" ]]; then
    git -C "$plugin_dir" pull --ff-only >/dev/null 2>&1 || warn "fzf-tab update failed"
    return 0
  fi
  log "Installing fzf-tab zsh plugin"
  mkdir -p "$(dirname "$plugin_dir")"
  git clone --depth 1 https://github.com/Aloxaf/fzf-tab "$plugin_dir" >/dev/null 2>&1 \
    || warn "fzf-tab install failed"
}

install_gext() {
  have gext && return 0
  if ! have pipx; then
    warn "pipx not found; skipping gext install"
    return 0
  fi
  log "Installing gext (gnome-extensions-cli)"
  pipx install gnome-extensions-cli >/dev/null 2>&1 || warn "Failed to install gext via pipx; GNOME extensions may need manual install"
}

bootstrap_role_vendors() {
  # Always install base vendor tools regardless of role
  install_mise_toolchains
  install_uv_if_missing
  install_rustup_if_missing
  install_fzf_tab
  install_yq

  case "$1" in
    web)
      install_mkcert
      install_mongosh
      install_usql
      ;;
    mobile)
      install_flutter_sdk
      install_android_cmdline_tools
      install_maestro
      install_bundletool
      install_flutter_distributor
      ;;
    devops)
      install_terragrunt
      install_stern
      install_trivy
      install_sops
      install_cosign
      install_kind
      install_k9s
      install_kubectx_tools
      install_minikube
      install_google_cloud_cli
      install_argocd
      install_flux
      install_gitleaks
      install_trufflehog
      install_tflint
      install_dive
      install_hadolint
      install_act
      install_kubeseal
      install_skaffold
      install_syft
      install_vault
      install_eksctl
      install_flyctl
      ;;
  esac
}

install_jetbrains_toolbox() {
  have jetbrains-toolbox && return 0
  log "Installing JetBrains Toolbox"
  local extract_dir="$VENDOR_TMP_DIR/jetbrains-toolbox"
  local archive="$VENDOR_TMP_DIR/jetbrains-toolbox.tar.gz"
  rm -rf "$extract_dir"
  mkdir -p "$extract_dir" "$VENDOR_TMP_DIR" "$HOME/.local/bin"
  
  local link
  link="$(curl -fsSL "https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release" | grep -oP '"linux":\{"link":"\K[^"]+' || true)"
  
  if [[ -z "$link" ]]; then
    record_vendor_failure "jetbrains-toolbox"
    return 1
  fi
  
  download_release_asset "$link" "$archive"
  tar -xzf "$archive" -C "$extract_dir" --strip-components=1
  if [[ -f "$extract_dir/jetbrains-toolbox" ]]; then
    install -m 0755 "$extract_dir/jetbrains-toolbox" "$HOME/.local/bin/jetbrains-toolbox"
  else
    record_vendor_failure "jetbrains-toolbox"
  fi
  rm -rf "$extract_dir" "$archive"
}
