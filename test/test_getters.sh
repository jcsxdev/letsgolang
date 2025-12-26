#!/bin/sh
#
# test_getters.sh - Unit tests for the getter functions in letsgolang.sh.
#
# This script validates utility functions responsible for data transformation,
# version parsing, and URL extraction.
#
# shellcheck disable=SC3043 # In POSIX sh, local is undefined but widely supported.

set -u

export SOURCED_FOR_TESTING=true

# --- Setup ---

# shellcheck disable=SC1091 # Not following.
. ./src/letsgolang.sh
# shellcheck disable=SC1091 # Not following.
. ./test/assert.sh

######################################################################
# Test Cases
######################################################################

# test_get_version_to_num_conversion: Validates conversion of semver strings to integers.
test_get_version_to_num_conversion() {
  local _result
  _result=$(get_version_to_num_conversion --version "1.2.3")
  _assert_equals "10203" "$_result" "Should convert 1.2.3 to 10203"

  _result=$(get_version_to_num_conversion --version "2.10.5")
  _assert_equals "21005" "$_result" "Should convert 2.10.5 to 21005"
}

# test_get_diff_between_versions: Validates version difference calculations.
test_get_diff_between_versions() {
  local _result
  _result=$(get_diff_between_versions --v1 "1.2.3" --v2 "1.2.4")
  _assert_equals "1" "$_result" "Should return 1 for patch difference"

  _result=$(get_diff_between_versions --v1 "1.2.3" --v2 "1.3.0")
  _assert_equals "97" "$_result" "Should return 97 for minor difference"

  _result=$(get_diff_between_versions --v1 "1.2.3" --v2 "2.0.0")
  _assert_equals "9797" "$_result" "Should return 9797 for major difference"
}

# test_get_base_url: Validates extraction of the base domain from URLs.
test_get_base_url() {
  local _result
  _result=$(get_base_url --url "https://example.com/some/path")
  _assert_equals "https://example.com" "$_result" "Should extract base URL"

  _result=$(get_base_url --url "http://localhost:8080/another/path?q=1")
  _assert_equals "http://localhost:8080" "$_result" "Should extract base URL with port"
}
