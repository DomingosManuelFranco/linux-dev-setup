#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# Source libraries
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/packages.sh"
source "$REPO_ROOT/lib/vendor.sh"

record_required_pkg_failure() {
  local pkg="$1"
  if [[ "$pkg" == "code" || "$pkg" == "google-chrome-stable" || "$pkg" == "google-chrome" || "$pkg" == "jetbrains-toolbox" || "$pkg" == "podman-desktop" ]]; then
    FAILED_OPTIONAL_GUI+=("$pkg")
  else
    FAILED_REQUIRED_PKGS+=("$pkg")
  fi
}

record_optional_failure() { FAILED_OPTIONAL_GUI+=("$1"); }

collect_packages_for_test() {
  local distro="$1"
  local -a selected=()
  local role pkg mapped

  for role in "${ROLES[@]}"; do
    while IFS= read -r pkg; do
      [[ -z "$pkg" ]] && continue
      if mapped="$(map_package "$distro" "$pkg" 2>/dev/null)"; then
        [[ -n "$mapped" ]] && selected+=("$mapped")
      else
        record_required_pkg_failure "$pkg"
      fi
    done < <(package_group "$role")
  done

  if [[ "${INSTALL_OPTIONAL:-0}" -eq 1 ]]; then
    while IFS= read -r pkg; do
      [[ -z "$pkg" ]] && continue
      if mapped="$(map_package "$distro" "$pkg" 2>/dev/null)"; then
        [[ -n "$mapped" ]] && selected+=("$mapped")
      else
        record_optional_failure "$pkg"
      fi
    done < <(package_group gui)
  fi

  printf '%s\n' "${selected[@]}"
}

pass() {
  printf "✅ %s\n" "$1"
}

fail() {
  printf "❌ %s\n" "$1"
  exit 1
}

test_install_script_parses() {
  echo "--- Running test_install_script_parses ---"

  bash -n "$REPO_ROOT/scripts/install.sh" || fail "scripts/install.sh failed shell syntax check"
  pass "install script parses"
}

# --- Test: distro_detection ---
test_distro_detection() {
  echo "--- Running test_distro_detection ---"

  # Create a mock os-release file
  local mock_os_release="/tmp/mock_os_release"

  # Test Arch
  cat <<'EOF' > "$mock_os_release"
ID=arch
EOF
  (
    res=$(detect_distro "$mock_os_release")
    [[ "$res" == "arch" ]] || fail "Expected arch, got $res"
  ) && pass "arch detection"

  # Test Ubuntu
  cat <<'EOF' > "$mock_os_release"
ID=ubuntu
EOF
  (
    res=$(detect_distro "$mock_os_release")
    [[ "$res" == "ubuntu" ]] || fail "Expected ubuntu, got $res"
  ) && pass "ubuntu detection"

  # Test Fedora
  cat <<'EOF' > "$mock_os_release"
ID=fedora
EOF
  (
    res=$(detect_distro "$mock_os_release")
    [[ "$res" == "fedora" ]] || fail "Expected fedora, got $res"
  ) && pass "fedora detection"

  # Test openSUSE
  cat <<'EOF' > "$mock_os_release"
ID=opensuse-tumbleweed
EOF
  (
    res=$(detect_distro "$mock_os_release")
    [[ "$res" == "opensuse" ]] || fail "Expected opensuse, got $res"
  ) && pass "opensuse detection"

  rm -f "$mock_os_release"
}

# --- Test: package_resolution ---
test_package_resolution() {
  echo "--- Running test_package_resolution ---"

  local res
  res=$(map_package arch neovim)
  [[ "$res" == "neovim" ]] || fail "Expected neovim for arch, got $res"
  pass "arch neovim mapping"

  res=$(map_package ubuntu mysql-client)
  [[ "$res" == "default-mysql-client" ]] || fail "Expected default-mysql-client for ubuntu, got $res"
  pass "ubuntu mysql-client mapping"

  res=$(map_package fedora google-chrome)
  [[ "$res" == "google-chrome-stable" ]] || fail "Expected google-chrome-stable for fedora, got $res"
  pass "fedora google-chrome mapping"

  res=$(map_package fedora wget)
  [[ "$res" == "wget2-wget" ]] || fail "Expected wget2-wget for fedora, got $res"
  pass "fedora wget mapping"

  res=$(map_package fedora p7zip)
  [[ "$res" == "7zip" ]] || fail "Expected 7zip for fedora, got $res"
  pass "fedora p7zip mapping"

  res=$(map_package arch p7zip)
  [[ "$res" == "7zip" ]] || fail "Expected 7zip for arch, got $res"
  pass "arch p7zip mapping"

  res=$(map_package arch python-neovim)
  [[ "$res" == "python-pynvim" ]] || fail "Expected python-pynvim for arch, got $res"
  pass "arch python-neovim mapping"

  res=$(map_package fedora mysql-client)
  [[ "$res" == "mariadb" ]] || fail "Expected mariadb for fedora, got $res"
  pass "fedora mysql-client mapping"

  res=$(map_package fedora docker-compose)
  [[ "$res" == "docker-compose" ]] || fail "Expected docker-compose for fedora, got $res"
  pass "fedora docker-compose mapping"

  res=$(map_package fedora docker-buildx)
  [[ "$res" == "docker-buildx" ]] || fail "Expected docker-buildx for fedora, got $res"
  pass "fedora docker-buildx mapping"

  # Test missing map (should return 1)
  if map_package ubuntu kubectl >/dev/null 2>&1; then
    fail "Expected map_package ubuntu kubectl to fail"
  else
    pass "ubuntu kubectl skips correctly"
  fi
}

test_manual_package_satisfaction() {
  echo "--- Running test_manual_package_satisfaction ---"

  (
    have() {
      [[ "$1" == "wget" || "$1" == "starship" || "$1" == "7zz" ]]
    }

    package_requirement_satisfied wget2-wget || fail "Expected wget2-wget to be satisfied by wget command"
    package_requirement_satisfied starship || fail "Expected starship to be satisfied by starship command"
    package_requirement_satisfied 7zip || fail "Expected 7zip to be satisfied by 7zz command"

    if package_requirement_satisfied neovim; then
      fail "Expected neovim package satisfaction check to remain unsupported"
    fi
  )

  pass "manual package satisfaction works"
}

test_terminal_font_configuration() {
  echo "--- Running test_terminal_font_configuration ---"

  grep -q 'font_family JetBrainsMono Nerd Font Mono' "$REPO_ROOT/config/home/.config/kitty/kitty.conf" \
    || fail "Expected Kitty to use JetBrainsMono Nerd Font Mono"
  grep -q 'family = "JetBrainsMono Nerd Font Mono"' "$REPO_ROOT/config/home/.config/alacritty/alacritty.toml" \
    || fail "Expected Alacritty to use JetBrainsMono Nerd Font Mono"
  grep -q 'DefaultProfile=Shell.profile' "$REPO_ROOT/config/home/.config/konsolerc" \
    || fail "Expected Konsole default profile to be Shell.profile"
  grep -q 'ColorScheme=DankNight' "$REPO_ROOT/config/home/.local/share/konsole/Shell.profile" \
    || fail "Expected Konsole profile to use DankNight color scheme"
  grep -q 'Font=JetBrainsMono Nerd Font Mono,12,-1,5,50,0,0,0,0,0' "$REPO_ROOT/config/home/.local/share/konsole/Shell.profile" \
    || fail "Expected Konsole profile to use JetBrainsMono Nerd Font Mono"

  pass "terminal font configuration is consistent"
}

test_gnome_terminal_configuration() {
  echo "--- Running test_gnome_terminal_configuration ---"

  grep -q 'org.gnome.Terminal.ProfilesList' "$REPO_ROOT/scripts/apply-gnome.sh" \
    || fail "Expected GNOME apply script to configure GNOME Terminal when available"
  grep -q "JetBrainsMono Nerd Font Mono 12" "$REPO_ROOT/scripts/apply-gnome.sh" \
    || fail "Expected GNOME apply script to set GNOME Terminal font"
  grep -q "org.gnome.Console.desktop org.gnome.Terminal.desktop kgx.desktop gnome-terminal.desktop" "$REPO_ROOT/scripts/apply-gnome.sh" \
    || fail "Expected GNOME apply script to detect GNOME terminal desktop entries"

  pass "gnome terminal configuration is present"
}

test_neovim_configuration() {
  echo "--- Running test_neovim_configuration ---"

  grep -q 'folke/lazy.nvim' "$REPO_ROOT/config/home/.config/nvim/lua/config/lazy.lua" \
    || fail "Expected Neovim to bootstrap lazy.nvim"
  grep -q 'catppuccin/nvim' "$REPO_ROOT/config/home/.config/nvim/lua/plugins/ui.lua" \
    || fail "Expected Neovim UI config to include catppuccin"
  grep -q 'saghen/blink.cmp' "$REPO_ROOT/config/home/.config/nvim/lua/plugins/lsp.lua" \
    || fail "Expected Neovim LSP config to include blink.cmp"
  grep -q 'christoomey/vim-tmux-navigator' "$REPO_ROOT/config/home/.config/nvim/lua/plugins/tmux.lua" \
    || fail "Expected Neovim editor config to include tmux navigation"

  pass "neovim configuration is present"
}

test_tmux_plugin_configuration() {
  echo "--- Running test_tmux_plugin_configuration ---"

  grep -q "tmux-plugins/tpm" "$REPO_ROOT/config/home/.tmux.conf" \
    || fail "Expected tmux config to include TPM"
  grep -q "tmux-plugins/tmux-resurrect" "$REPO_ROOT/config/home/.tmux.conf" \
    || fail "Expected tmux config to include tmux-resurrect"
  grep -q "christoomey/vim-tmux-navigator" "$REPO_ROOT/config/home/.tmux.conf" \
    || fail "Expected tmux config to include vim-tmux-navigator"
  grep -q "run '~/.tmux/plugins/tpm/tpm'" "$REPO_ROOT/config/home/.tmux.conf" \
    || fail "Expected tmux config to initialize TPM"

  pass "tmux plugin configuration is present"
}

test_reconcile_fedora_conflicts() {
  echo "--- Running test_reconcile_fedora_conflicts ---"

  local -a reconciled=()
  mapfile -t reconciled < <(reconcile_packages fedora moby-engine podman podman-docker buildah)

  [[ " ${reconciled[*]} " == *" moby-engine "* ]] || fail "Expected moby-engine to be kept"
  [[ " ${reconciled[*]} " == *" podman "* ]] || fail "Expected podman to be kept"
  [[ " ${reconciled[*]} " == *" buildah "* ]] || fail "Expected buildah to be kept"
  [[ " ${reconciled[*]} " != *" podman-docker "* ]] || fail "Expected podman-docker to be dropped when moby-engine is selected"

  pass "fedora package conflicts are reconciled"
}

# --- Test: failure_aggregations ---
test_failure_aggregations() {
  echo "--- Running test_failure_aggregations ---"
  
  FAILED_REQUIRED_PKGS=()
  FAILED_VENDOR_TOOLS=()
  FAILED_SETUP=()
  FAILED_OPTIONAL_GUI=()

  record_required_pkg_failure "neovim"
  record_required_pkg_failure "git"
  record_required_pkg_failure "google-chrome"
  
  [[ "${#FAILED_REQUIRED_PKGS[@]}" -eq 2 ]] || fail "Expected 2 required pkg failures"
  [[ "${FAILED_REQUIRED_PKGS[0]}" == "neovim" ]] || fail "Expected neovim as failure"
  [[ "${FAILED_OPTIONAL_GUI[0]}" == "google-chrome" ]] || fail "Expected google-chrome as optional gui failure"
  
  pass "failure aggregation tracks correctly"
}

test_collect_packages_records_unmapped_required() {
  echo "--- Running test_collect_packages_records_unmapped_required ---"

  FAILED_REQUIRED_PKGS=()
  FAILED_OPTIONAL_GUI=()
  ROLES=(devops)
  INSTALL_OPTIONAL=0

  collect_packages_for_test ubuntu >/dev/null

  [[ " ${FAILED_REQUIRED_PKGS[*]} " == *" kubectl "* ]] || fail "Expected kubectl to be recorded as required failure"
  [[ " ${FAILED_REQUIRED_PKGS[*]} " == *" helm "* ]] || fail "Expected helm to be recorded as required failure"
  [[ " ${FAILED_REQUIRED_PKGS[*]} " == *" terraform "* ]] || fail "Expected terraform to be recorded as required failure"
  [[ " ${FAILED_REQUIRED_PKGS[*]} " == *" packer "* ]] || fail "Expected packer to be recorded as required failure"
  [[ " ${FAILED_REQUIRED_PKGS[*]} " == *" azure-cli "* ]] || fail "Expected azure-cli to be recorded as required failure"

  pass "unmapped required packages are recorded"
}

test_collect_packages_records_unmapped_optional() {
  echo "--- Running test_collect_packages_records_unmapped_optional ---"

  FAILED_REQUIRED_PKGS=()
  FAILED_OPTIONAL_GUI=()
  ROLES=(base)
  INSTALL_OPTIONAL=1

  collect_packages_for_test ubuntu >/dev/null

  [[ " ${FAILED_OPTIONAL_GUI[*]} " == *" code "* ]] || fail "Expected code to be recorded as optional failure"
  [[ " ${FAILED_OPTIONAL_GUI[*]} " == *" google-chrome "* ]] || fail "Expected google-chrome to be recorded as optional failure"
  [[ " ${FAILED_OPTIONAL_GUI[*]} " == *" podman-desktop "* ]] || fail "Expected podman-desktop to be recorded as optional failure"
  [[ " ${FAILED_OPTIONAL_GUI[*]} " == *" jetbrains-toolbox "* ]] || fail "Expected jetbrains-toolbox to be recorded as optional failure"

  pass "unmapped optional packages are recorded"
}

test_setup_git_non_interactive() {
  echo "--- Running test_setup_git_non_interactive ---"
  
  local original_home="$HOME"
  local fake_home="/tmp/fake_home_$$"
  mkdir -p "$fake_home"
  export HOME="$fake_home"
  
  # Export test variables
  export NON_INTERACTIVE=1
  export GIT_NAME="Test User"
  export GIT_EMAIL="test@example.com"
  
  setup_git >/dev/null 2>&1
  
  # Verify config
  local actual_name
  actual_name=$(git config --global user.name)
  [[ "$actual_name" == "Test User" ]] || fail "Expected 'Test User', got '$actual_name'"
  
  local actual_email
  actual_email=$(git config --global user.email)
  [[ "$actual_email" == "test@example.com" ]] || fail "Expected 'test@example.com', got '$actual_email'"
  
  # Clean up
  rm -rf "$fake_home"
  export HOME="$original_home"
  pass "git config non-interactive"
}

test_setup_github_non_interactive_token() {
  echo "--- Running test_setup_github_non_interactive_token ---"

  local original_home="$HOME"
  local original_ssh_auth_sock="${SSH_AUTH_SOCK:-}"
  local fake_home="/tmp/fake_github_home_$$"
  local state_dir="/tmp/fake_gh_state_$$"
  mkdir -p "$fake_home/.ssh" "$state_dir"
  export HOME="$fake_home"
  export NON_INTERACTIVE=1
  export GH_TOKEN="token-123"
  export SSH_AUTH_SOCK="$state_dir/agent.sock"

  git config --global user.email "test@example.com"

  gh() {
    if [[ "$1" == "auth" && "$2" == "status" ]]; then
      [[ -f "$state_dir/logged_in" ]]
      return
    fi

    if [[ "$1" == "auth" && "$2" == "login" ]]; then
      local token
      IFS= read -r token
      if [[ "$token" == "token-123" ]]; then
        : > "$state_dir/logged_in"
        return 0
      fi
      return 1
    fi

    if [[ "$1" == "api" && "$2" == "user" ]]; then
      printf 'tester\n'
      return 0
    fi

    if [[ "$1" == "ssh-key" && "$2" == "list" ]]; then
      return 0
    fi

    if [[ "$1" == "ssh-key" && "$2" == "add" ]]; then
      : > "$state_dir/key_uploaded"
      return 0
    fi

    return 1
  }

  ssh-keygen() {
    local out_file=""
    while [[ $# -gt 0 ]]; do
      if [[ "$1" == "-f" ]]; then
        out_file="$2"
        shift 2
      else
        shift
      fi
    done

    [[ -n "$out_file" ]] || return 1
    printf 'private\n' > "$out_file"
    printf 'ssh-ed25519 AAAATESTKEY test@example.com\n' > "$out_file.pub"
  }

  ssh-add() {
    return 0
  }

  FAILED_SETUP=()
  WARNINGS=()

  setup_github >/dev/null 2>&1

  [[ ${#FAILED_SETUP[@]} -eq 0 ]] || fail "Expected setup_github token auth to succeed"
  [[ -f "$state_dir/logged_in" ]] || fail "Expected gh auth login to be called"
  [[ -f "$fake_home/.ssh/id_ed25519" ]] || fail "Expected SSH private key to be created"
  [[ -f "$state_dir/key_uploaded" ]] || fail "Expected SSH key upload to be attempted"

  unset -f gh ssh-keygen ssh-add
  rm -rf "$fake_home" "$state_dir"
  export HOME="$original_home"
  if [[ -n "$original_ssh_auth_sock" ]]; then
    export SSH_AUTH_SOCK="$original_ssh_auth_sock"
  else
    unset SSH_AUTH_SOCK
  fi
  unset GH_TOKEN
  pass "github token auth non-interactive"
}

test_setup_github_missing_public_key_scope_warns() {
  echo "--- Running test_setup_github_missing_public_key_scope_warns ---"

  local original_home="$HOME"
  local original_ssh_auth_sock="${SSH_AUTH_SOCK:-}"
  local fake_home="/tmp/fake_github_scope_home_$$"
  mkdir -p "$fake_home/.ssh"
  export HOME="$fake_home"
  export NON_INTERACTIVE=1
  export GH_TOKEN="token-123"
  export SSH_AUTH_SOCK="/tmp/fake_github_scope_agent_$$.sock"

  git config --global user.email "test@example.com"
  printf 'private\n' > "$fake_home/.ssh/id_ed25519"
  printf 'ssh-ed25519 AAAATESTKEY test@example.com\n' > "$fake_home/.ssh/id_ed25519.pub"

  gh() {
    if [[ "$1" == "auth" && "$2" == "status" ]]; then
      return 0
    fi

    if [[ "$1" == "api" && "$2" == "user" ]]; then
      printf 'tester\n'
      return 0
    fi

    if [[ "$1" == "ssh-key" && "$2" == "list" ]]; then
      printf 'HTTP 404: Not Found\nThis API operation needs the "admin:public_key" scope.\n'
      return 1
    fi

    if [[ "$1" == "ssh-key" && "$2" == "add" ]]; then
      printf 'This API operation needs the "admin:public_key" scope.\n'
      return 1
    fi

    return 1
  }

  ssh-add() {
    return 0
  }

  FAILED_SETUP=()
  WARNINGS=()

  setup_github >/dev/null 2>&1

  [[ ${#FAILED_SETUP[@]} -eq 0 ]] || fail "Expected missing admin:public_key scope to be non-fatal"
  [[ " ${WARNINGS[*]} " == *"admin:public_key scope"* ]] || fail "Expected missing scope warning to be recorded"

  unset -f gh ssh-add
  rm -rf "$fake_home"
  export HOME="$original_home"
  if [[ -n "$original_ssh_auth_sock" ]]; then
    export SSH_AUTH_SOCK="$original_ssh_auth_sock"
  else
    unset SSH_AUTH_SOCK
  fi
  unset GH_TOKEN
  pass "github missing public key scope warns"
}

test_install_jetbrains_toolbox_optional_failure() {
  echo "--- Running test_install_jetbrains_toolbox_optional_failure ---"

  local original_home="$HOME"
  local fake_home="/tmp/fake_toolbox_home_$$"
  local fake_tmp="/tmp/fake_toolbox_tmp_$$"
  mkdir -p "$fake_home" "$fake_tmp"
  export HOME="$fake_home"
  VENDOR_TMP_DIR="$fake_tmp"

  curl() {
    return 0
  }

  FAILED_OPTIONAL_GUI=()
  FAILED_VENDOR_TOOLS=()
  WARNINGS=()

  install_jetbrains_toolbox >/dev/null 2>&1

  [[ " ${FAILED_OPTIONAL_GUI[*]} " == *" jetbrains-toolbox "* ]] || fail "Expected JetBrains Toolbox optional failure to be recorded"
  [[ ${#FAILED_VENDOR_TOOLS[@]} -eq 0 ]] || fail "Expected JetBrains Toolbox not to count as vendor failure"
  [[ " ${WARNINGS[*]} " == *"JetBrains Toolbox metadata lookup failed"* ]] || fail "Expected JetBrains Toolbox warning to be recorded"

  unset -f curl
  rm -rf "$fake_home" "$fake_tmp"
  export HOME="$original_home"
  pass "jetbrains toolbox optional failure handling"
}

test_install_script_parses
test_distro_detection
test_package_resolution
test_manual_package_satisfaction
test_terminal_font_configuration
test_gnome_terminal_configuration
test_neovim_configuration
test_tmux_plugin_configuration
test_reconcile_fedora_conflicts
test_failure_aggregations
test_collect_packages_records_unmapped_required
test_collect_packages_records_unmapped_optional
test_setup_git_non_interactive
test_setup_github_non_interactive_token
test_setup_github_missing_public_key_scope_warns
test_install_jetbrains_toolbox_optional_failure

echo "All tests passed."
