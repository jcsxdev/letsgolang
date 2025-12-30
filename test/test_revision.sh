#!/bin/sh
#
# test_revision.sh - Unit tests for the metadata revision script.
#
# This script validates that scripts/revision.sh correctly synchronizes
# versioning constants with the Git repository state. It creates a
# temporary Git environment for isolated testing.
#
# shellcheck disable=SC3043 # In POSIX sh, local is undefined but widely supported.

set -u

export SOURCED_FOR_TESTING=true

# --- Setup ---

# shellcheck disable=SC1091 # Not following.
. ./src/letsgolang.sh
# shellcheck disable=SC1091 # Not following.
. ./test/assert.sh

# Global variable to track the temporary Git repository path.
_temp_test_dir=""

# setUp: Creates a temporary directory and initializes a Git repository for testing.
# This environment isolates the test from the main project repository.
setUp() {
  _temp_test_dir=$(get_temporary_dir)
  cd "$_temp_test_dir" || return 1
  git init >/dev/null
  git config user.email "test@example.com" >/dev/null
  git config user.name "Test User" >/dev/null
  git config commit.gpgSign false >/dev/null
  mkdir -p src
}

# tearDown: Removes the temporary test directory and restores the previous working directory.
tearDown() {
  if [ -n "$_temp_test_dir" ]; then
    # Default to parent directory if OLDPWD is not available.
    cd "${OLDPWD:-..}" || return 1
    rm -rf "$_temp_test_dir"
    _temp_test_dir=""
  fi
}

######################################################################
# Test Cases
######################################################################

# test_revision_updates_version_and_data: Validates that revision.sh updates
# version constants based on Git tags and commits.
test_revision_updates_version_and_data() {
  local _expected_version="1.2.3"
  local _current_commit
  local _current_date

  # Prepare a mock target script within the temporary Git repository.
  cp "${OLDPWD}/src/letsgolang.sh" "src/letsgolang.sh"
  chmod +w src/letsgolang.sh

  # Initialize Git state.
  git add src/letsgolang.sh
  git commit -m "feat: initial script" >/dev/null
  git tag "v$_expected_version"

  # Execute the revision script from the original project root.
  "${OLDPWD}/scripts/revision.sh" "src/letsgolang.sh" >/dev/null

  # Assertions
  _assert_contains "$(cat src/letsgolang.sh)" "G_SCRIPT_VERSION='$_expected_version'" "Version should be updated to the latest tag."

  _current_commit=$(git rev-parse --short HEAD)
  _assert_contains "$(cat src/letsgolang.sh)" "G_SCRIPT_COMMIT='$_current_commit'" "Commit hash should be updated."

  _current_date=$(date -u +'%Y-%m-%d')
  _assert_contains "$(cat src/letsgolang.sh)" "G_SCRIPT_DATE='$_current_date'" "Date should be updated."
}

# test_revision_defaults_to_zero_version: Validates that revision.sh defaults
# to '0.0.0' when no Git tags are found.
test_revision_defaults_to_zero_version() {
  # Prepare a mock target script within the temporary Git repository (no tags).
  cp "${OLDPWD}/src/letsgolang.sh" "src/letsgolang.sh"
  chmod +w src/letsgolang.sh

  git add src/letsgolang.sh
  git commit -m "feat: initial script without tag" >/dev/null

  # Execute the revision script.
  "${OLDPWD}/scripts/revision.sh" "src/letsgolang.sh" >/dev/null

  # Assertion: Version should be 0.0.0
  _assert_contains "$(cat src/letsgolang.sh)" "G_SCRIPT_VERSION='0.0.0'" "Version should default to 0.0.0 when no tags exist."
}

# test_revision_handles_empty_initial_values: Edge case test to ensure the script
# can "heal" a file where constants are empty and unquoted.
test_revision_handles_empty_initial_values() {
  local _target="src/empty_vars.sh"
  local _expected="2.0.0"

  # Create a file with empty and unquoted values.
  printf "readonly G_SCRIPT_VERSION=\nreadonly G_SCRIPT_COMMIT=\nreadonly G_SCRIPT_DATE=\n" >"$_target"

  # Set Git state.
  git tag "v$_expected"

  # Execute revision.
  "${OLDPWD}/scripts/revision.sh" "$_target" >/dev/null

  # Assertions
  _assert_contains "$(cat "$_target")" "G_SCRIPT_VERSION='$_expected'" "Should heal and update empty unquoted version."
  _assert_contains "$(cat "$_target")" "G_SCRIPT_COMMIT=" "Should update empty unquoted commit."
  _assert_contains "$(cat "$_target")" "G_SCRIPT_DATE=" "Should update empty unquoted date."
}

# test_revision_fails_on_invalid_target: Ensures the script fails gracefully
# when the target file lacks the required versioning markers.
test_revision_fails_on_invalid_target() {
  local _test_output

  # Create an invalid target file.
  printf "this is not a valid file\n" >src/invalid.sh
  git add . && git commit -m "add invalid" >/dev/null

  # Execute and capture failure.
  if ! _test_output=$("${OLDPWD}/scripts/revision.sh" "src/invalid.sh" 2>&1); then
    _assert_contains "$_test_output" "Validation failed" "Should print validation error for missing G_SCRIPT_VERSION."
  else
    _assert_equals "a failure" "a success" "Should fail when target file is invalid."
  fi
}
