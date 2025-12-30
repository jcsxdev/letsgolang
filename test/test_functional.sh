#!/bin/sh
#
# test_functional.sh - Functional integration tests for letsgolang.sh
#
# shellcheck disable=SC3043 # In POSIX sh, local is undefined but supported by many shells.

# --- Setup ---

# shellcheck disable=SC1091
. ./test/assert.sh

# Path to the target script
TARGET="./src/letsgolang.sh"

# Helper to run the target script as an executable, unsetting SOURCED_FOR_TESTING
run_target() {
  SOURCED_FOR_TESTING="" "$TARGET" "$@"
}

test_no_color_support() {
  local _output
  # Run with NO_COLOR=true and check that no ANSI escape codes are present.
  # \033[ is the start of most ANSI sequences.
  _output=$(NO_COLOR=true run_target --help)
  if echo "$_output" | grep -q "\033\["; then
    _assert_equals "clean text" "colored text" "Output should not contain ANSI colors when NO_COLOR is set."
  fi
}

test_version_output_format() {
  local _output
  _output=$(run_target --version)
  # Expected format: letsgolang 0.1.0 (commit date)
  if ! echo "$_output" | grep -q "^letsgolang [0-9]\+\.[0-9]\+\.[0-9]\+"; then
    _assert_equals "semver format" "$_output" "Version output should follow semver format."
  fi
}

test_assume_yes_acceptance() {
  # Just verify it accepts the flag.
  run_target --assume-yes --help >/dev/null
}