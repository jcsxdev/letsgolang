#!/bin/sh

# test_manual_checksum.sh - Tests for the --checksum option.
#
# This script validates that the manual checksum override works as expected,
# enforcing verification against the user-provided value and skipping
# remote scraping.

# shellcheck disable=SC3043 # In POSIX sh, local is undefined but supported by many shells.
# shellcheck disable=SC2329 # Mocks are called by sourced functions

fail() {
  printf "FAIL: %s\n" "$1"
  return 1
}

test_args_parsing_checksum() {
  get_main_opts --checksum "myManualChecksum123"
  _assert_equals "myManualChecksum123" "$g_manual_checksum" "Should parse --checksum argument"
}

test_args_parsing_checksum_missing_arg() {
  if get_main_opts --checksum >/dev/null 2>&1; then
    fail "Should fail when --checksum is missing argument"
  fi
}

test_manual_checksum_success() {
  # Setup global state
  g_manual_checksum="good_hash"
  g_installation_filename="dummy.tar.gz" # Required check in process_step4

  # Create dummy file
  touch "$g_installation_filename"

  # Mock get_checksum to return our expected local hash
  get_checksum() {
    printf "good_hash"
    return 0
  }

  # Mock logging to avoid pollution
  log_info() { :; }
  log_success() { :; }

  # Execution
  # This should return 0 (success) directly without calling remote URL getters
  if ! process_step4; then
    rm "$g_installation_filename"
    fail "process_step4 should succeed when manual checksum matches local checksum"
  fi
  rm "$g_installation_filename"
}

test_manual_checksum_mismatch() {
  # Setup global state
  g_manual_checksum="good_hash"
  g_installation_filename="dummy.tar.gz" # Required check in process_step4

  # Create dummy file
  touch "$g_installation_filename"

  # Mock get_checksum to return a BAD hash
  get_checksum() {
    printf "bad_hash"
    return 0
  }

  # Mock logging
  log_info() { :; }
  log_error() { :; }

  # Execution
  if process_step4; then
    rm "$g_installation_filename"
    fail "process_step4 should fail when manual checksum differs from local checksum"
  fi
  rm "$g_installation_filename"
}

# Load the assertion library
# shellcheck disable=SC1091
. ./test/assert.sh

# Load the script under test
# shellcheck disable=SC1091
. ./src/letsgolang.sh
