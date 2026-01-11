#!/bin/sh
#
# test_simulation.sh - Full installation flow simulation (Happy Path)
#
# This test mocks network interaction (curl) to simulate a complete
# installation run. It ensures all internal logic wires together correctly.
#
# shellcheck disable=SC3043
# shellcheck disable=SC2329
# shellcheck disable=SC2034

set -u

# shellcheck disable=SC1091
. ./test/assert.sh

# Source the target script (skip main execution)
export SOURCED_FOR_TESTING=true
# shellcheck disable=SC1091
. ./src/letsgolang.sh

# --- Mocks & Setup ---

setup() {
  # Create isolated test environment
  TEST_ROOT=$(mktemp -d)

  # Override get_temporary_dir to return our isolated temp dir
  get_temporary_dir() {
    echo "$TEST_ROOT/tmp"
    return 0
  }
  mkdir -p "$TEST_ROOT/tmp"

  # Override get_go_dir to install into our isolated root
  get_go_dir() {
    echo "$TEST_ROOT/local/go"
    return 0
  }
  mkdir -p "$TEST_ROOT/local"

  # Override HOME to prevent touching real config files
  HOME="$TEST_ROOT/home"
  mkdir -p "$HOME"
}

teardown() {
  rm -rf "$TEST_ROOT"
}

# Mock curl to simulate network responses
curl() {
  local _arg
  local _is_version=false
  local _is_download=false
  local _is_checksum=false
  local _is_head=false
  local _url=""

  # Naive argument parsing for simulation
  for _arg in "$@"; do
    case "$_arg" in
      *VERSION?m=text) _is_version=true ;;
      *.tar.gz)
        _is_download=true
        _url="$_arg"
        ;;
      */dl/) _is_checksum=true ;;
      -I) _is_head=true ;;
    esac
  done

  # 1. Version Check
  if [ "$_is_version" = true ]; then
    # Return a fake version
    echo "go1.99.9"
    return 0
  fi

  # 2. Connection Check (HEAD request)
  if [ "$_is_head" = true ]; then
    echo "200"
    return 0
  fi

  # 3. Download Artifact
  if [ "$_is_download" = true ]; then
    local _filename="${_url##*/}"
    touch "$_filename"
    return 0
  fi

  # 4. Checksums
  if [ "$_is_checksum" = true ]; then
    # Return the SHA256 of an empty file (which is what we touched above)
    # matching the filename we expect.
    # SHA256(empty) = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
    echo "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  go1.99.9.linux-amd64.tar.gz"
    echo "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e  go1.99.9.linux-amd64.tar.gz"
    return 0
  fi
}

# Mock tar to verify extraction attempted
tar() {
  # Leave a trace for validation
  echo "TAR_EXECUTED" >"$TEST_ROOT/tar_called"
  return 0
}

# --- Tests ---

test_simulate_fresh_install() {
  setup

  # Force architecture to match our checksum logic
  get_machine_architecture_tag() { echo "amd64"; }

  # Prevent real shell reload
  g_reload_command=""

  # Force a specific profile for deterministic testing
  # letsgolang.sh uses $SHELL to decide. We'll simulate a generic shell.
  SHELL="/bin/sh"

  # Run the main installation routine
  local _out
  if ! _out=$(process_main_routine 2>&1); then
    echo "$_out"
    _assert_equals 0 1 "process_main_routine failed during simulation"
  fi

  # 1. Verify Downloaded Artifact
  # Step 3 downloads to a temp dir which is cleaned up.
  # But we can verify Step 5's extraction logic via our tar mock.

  # 2. Verify Tar Call
  if [ ! -f "$TEST_ROOT/tar_called" ]; then
    _assert_equals "tar trace file" "missing" "The tar command was never executed"
  fi

  # 3. Verify Final Directory Structure
  if [ ! -d "$TEST_ROOT/local/go" ]; then
    _assert_equals "directory exists" "$TEST_ROOT/local/go" "Go installation directory was not created"
  fi

  # 4. Verify Shell Configuration
  # For /bin/sh, it defaults to .profile
  if [ ! -f "$HOME/.profile" ]; then
    _assert_equals "profile file exists" "$HOME/.profile" "Shell configuration file was not created"
  fi

  if ! grep -q "GOROOT=\"\$HOME/.local/opt/go\"" "$HOME/.profile"; then
    _assert_equals "GOROOT in profile" "not found" "GOROOT was not correctly exported in .profile"
  fi

  teardown
}
