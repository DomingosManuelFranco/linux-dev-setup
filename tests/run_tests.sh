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

  # Test missing map (should return 1)
  if map_package ubuntu kubectl >/dev/null 2>&1; then
    fail "Expected map_package ubuntu kubectl to fail"
  else
    pass "ubuntu kubectl skips correctly"
  fi
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
test_failure_aggregations
test_collect_packages_records_unmapped_required
test_collect_packages_records_unmapped_optional
test_setup_git_non_interactive
test_setup_github_non_interactive_token
test_install_jetbrains_toolbox_optional_failure

echo "All tests passed."
