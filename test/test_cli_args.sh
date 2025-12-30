#!/bin/sh
#
# test_cli_args.sh - CLI argument integration tests for letsgolang.sh
#

# --- Setup ---

# shellcheck disable=SC1091
. ./test/assert.sh

# Path to the target script
TARGET="./src/letsgolang.sh"

# Helper to run the target script as an executable, unsetting SOURCED_FOR_TESTING
run_target() {
  SOURCED_FOR_TESTING= "$TARGET" "$@"
}

test_help_short() {
  run_target -h >/dev/null
}

test_help_long() {
  run_target --help >/dev/null
}

test_version_short() {
  run_target -V >/dev/null
}

test_version_long() {
  run_target --version >/dev/null
}

test_invalid_option() {
  local _output
  if _output=$(run_target --invalid-option 2>&1); then
    _assert_equals "failure" "success" "Script should fail on unknown options."
  else
    _assert_contains "$_output" "Unknown option" "Error message should mention unknown option."
  fi
}

test_quiet_mode_arg() {
  run_target --quiet --help >/dev/null
}

test_verbose_mode_arg() {
  run_target --verbose --help >/dev/null
}
