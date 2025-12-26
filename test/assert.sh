#!/bin/sh
#
# assert.sh - Simple assertion library for shell script testing.
#
# This library provides basic assertion functions to validate test results.
# It is designed to be POSIX-compliant and used within the letsgolang project.
#
# shellcheck disable=SC3043 # In POSIX sh, local is undefined but widely supported.

set -u

# _assert_equals: Validates that two values are identical.
# Arguments:
#   $1: Expected value
#   $2: Actual value
#   $3: Failure message (optional)
# Returns: 0 on success, 1 on failure.
_assert_equals() {
  local _expected="$1"
  local _actual="$2"
  local _message="${3:-}"

  if [ "$_actual" = "$_expected" ]; then
    return 0
  else
    # Use printf for better formatting control
    printf "\nASSERTION FAILED: %s\n  Expected: '%s'\n  Actual:   '%s'\n" "$_message" "$_expected" "$_actual"
    return 1
  fi
}

# _assert_contains: Validates that a string contains a specific substring.
# Arguments:
#   $1: The full string to check
#   $2: The substring to look for
#   $3: Failure message (optional)
# Returns: 0 on success, 1 on failure.
_assert_contains() {
  local _string="$1"
  local _substring="$2"
  local _message="${3:-}"

  if printf "%s" "$_string" | grep -q -- "$_substring"; then
    return 0
  else
    # Use printf for better formatting control
    printf "\nASSERTION FAILED: %s\n  Expected string to contain: '%s'\n  Actual string: '%s'\n" "$_message" "$_substring" "$_string"
    return 1
  fi
}
