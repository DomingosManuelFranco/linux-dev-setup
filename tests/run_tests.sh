#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# Source libraries
source "$REPO_ROOT/lib/common.sh"
source "$REPO_ROOT/lib/packages.sh"

pass() {
  printf "✅ %s\n" "$1"
}

fail() {
  printf "❌ %s\n" "$1"
  exit 1
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

test_setup_git_non_interactive() {
  echo "--- Running test_setup_git_non_interactive ---"
  
  # Setup fake HOME
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
  pass "git config non-interactive"
}

test_distro_detection
test_package_resolution
test_failure_aggregations
test_setup_git_non_interactive

echo "All tests passed."
