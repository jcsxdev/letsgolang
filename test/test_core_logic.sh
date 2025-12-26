#!/bin/sh
#
# test_core_logic.sh - Unit tests for the core logic of letsgolang.sh.
#
# This script validates fundamental internal functions such as color detection
# and environment state management.
#
# shellcheck disable=SC3043 # In POSIX sh, local is undefined but widely supported.

set -u

export SOURCED_FOR_TESTING=true

# --- Setup ---

# Create a temporary, mutable version of the script for testing.
# This allows overriding readonly variables during the test session.
umask 0077
_temp_script=$(mktemp "/tmp/script_test.XXXXXX")
trap 'rm -f "$_temp_script"' EXIT HUP INT QUIT TERM

sed -e 's/readonly G_SCRIPT_VERSION/G_SCRIPT_VERSION/' \
  -e 's/readonly G_SCRIPT_COMMIT/G_SCRIPT_COMMIT/' \
  -e 's/readonly G_SCRIPT_DATE/G_SCRIPT_DATE/' \
  ./src/letsgolang.sh >"$_temp_script"

# Source the mutable script and the assert library.
# shellcheck source=/dev/null
. "$_temp_script"

# shellcheck disable=SC1091 # Not following.
. ./test/assert.sh

######################################################################
# Helper Functions
######################################################################

# reset_no_color: Restores the NO_COLOR variable to its state before the test.
# Uses the global _old_no_color variable set within test functions.
reset_no_color() {
  if [ "${_old_no_color+x}" = "x" ]; then
    NO_COLOR="$_old_no_color"
  else
    unset NO_COLOR
  fi
}

######################################################################
# Test Cases
######################################################################

# test_is_no_color: Validates the NO_COLOR standard compliance.
# It checks if the script correctly detects when colors should be disabled.
test_is_no_color() {
  local _old_no_color="${NO_COLOR:-}" # Save current state
  local _exit_code

  # Test Case: Unset NO_COLOR
  unset NO_COLOR
  printf "Testing unset NO_COLOR...\n"
  is_no_color
  _exit_code=$?
  printf "Exit code after unset NO_COLOR: %d\n" "$_exit_code"
  _assert_equals "1" "$_exit_code" "is_no_color should return 1 when NO_COLOR is unset."

  # Test Case: Empty NO_COLOR
  NO_COLOR=""
  printf "Testing empty NO_COLOR...\n"
  is_no_color
  _exit_code=$?
  printf "Exit code after empty NO_COLOR: %d\n" "$_exit_code"
  _assert_equals "1" "$_exit_code" "is_no_color should return 1 when NO_COLOR is empty."

  # Test Case: NO_COLOR='true'
  NO_COLOR="true"
  printf "Testing NO_COLOR='true'...\n"
  is_no_color
  _exit_code=$?
  printf "Exit code after NO_COLOR='true': %d\n" "$_exit_code"
  _assert_equals "0" "$_exit_code" "is_no_color should return 0 when NO_COLOR is 'true'."

  # Test Case: NO_COLOR='1'
  NO_COLOR="1"
  printf "Testing NO_COLOR='1'...\n"
  is_no_color
  _exit_code=$?
  printf "Exit code after NO_COLOR='1': %d\n" "$_exit_code"
  _assert_equals "0" "$_exit_code" "is_no_color should return 0 when NO_COLOR is '1'."

  # Restoration
  printf "Restoring original NO_COLOR state...\n"
  reset_no_color
}
