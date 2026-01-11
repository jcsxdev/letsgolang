#!/bin/sh
#
# test_release_keys.sh - Unit tests for GPG logic
#
# shellcheck disable=SC3043
# shellcheck disable=SC2329

set -u

export SOURCED_FOR_TESTING=true

# --- Mocks ---

git() {
  echo "mock-git-output"
}

# The underlying gpg command mock
# We use this to spy on the arguments passed by gpg_wrapper
gpg() {
  # If the first argument is --homedir, we verify it matches expected
  if [ "$1" = "--homedir" ]; then
    # We export a variable to signal the test that homedir was received
    # (In a subshell context this is tricky, but strictly for unit testing logic flow)
    echo "GPG_CALLED_WITH_HOMEDIR=$2"
  fi
  return 0
}

# shellcheck disable=SC1091
. ./scripts/release.sh
# shellcheck disable=SC1091
. ./test/assert.sh

######################################################################
# Tests for validate_sign_key
######################################################################

test_validate_sign_key_valid_long_id() {
  # 16 hex characters (FAKE TEST VALUE)
  validate_sign_key "1234567890ABCDEF"
  _assert_equals "0" "$?" "Should accept valid 16-char hex ID"
}

test_validate_sign_key_valid_fingerprint() {
  # 40 hex characters (FAKE TEST VALUE)
  validate_sign_key "1234567890ABCDEF1234567890ABCDEF12345678"
  _assert_equals "0" "$?" "Should accept valid 40-char hex fingerprint"
}

test_validate_sign_key_invalid_short_id() {
  local _ret=0
  (validate_sign_key "12345678" >/dev/null 2>&1) || _ret=$?
  _assert_equals "1" "$_ret" "Should reject 8-char short ID"
}

test_validate_sign_key_invalid_non_hex() {
  local _ret=0
  (validate_sign_key "GPGKEYISNOTHEX!!" >/dev/null 2>&1) || _ret=$?
  _assert_equals "1" "$_ret" "Should reject non-hex characters"
}

test_validate_sign_key_invalid_empty() {
  local _ret=0
  (validate_sign_key "" >/dev/null 2>&1) || _ret=$?
  _assert_equals "1" "$_ret" "Should reject empty input"
}

test_validate_sign_key_invalid_length() {
  local _ret=0
  # 15 chars
  (validate_sign_key "1234567890ABCDE" >/dev/null 2>&1) || _ret=$?
  _assert_equals "1" "$_ret" "Should reject invalid length (15)"

  _ret=0
  # 17 chars
  (validate_sign_key "1234567890ABCDEFG" >/dev/null 2>&1) || _ret=$?
  _assert_equals "1" "$_ret" "Should reject invalid length (17)"
}

######################################################################
# Tests for resolve_sign_key
######################################################################

test_resolve_sign_key_explicit_argument() {
  # FAKE TEST KEY
  SIGN_KEY="1234567890ABCDEF"

  # Mock gpg_wrapper to verify validation logic (bypass real execution)
  # But here we are testing resolve_sign_key, which calls gpg_wrapper --list-keys
  # We need to mock gpg_wrapper or ensure gpg mock handles it.
  # The updated release.sh uses gpg_wrapper which calls mocked gpg.

  resolve_sign_key
  _assert_equals "0" "$?" "Should succeed with valid explicit SIGN_KEY"
}

test_resolve_sign_key_git_local_config() {
  SIGN_KEY=""

  # Mock git to return a key for local config (FAKE)
  git() {
    if [ "$1" = "config" ] && [ "$2" = "--local" ]; then
      echo "AAAAABBBBBCCCCCD"
      return 0
    fi
    return 1
  }

  resolve_sign_key
  _assert_equals "0" "$?" "Should resolve key from git config --local"
  _assert_equals "AAAAABBBBBCCCCCD" "$SIGN_KEY" "Should set SIGN_KEY from git local"
}

test_resolve_sign_key_git_global_fallback() {
  SIGN_KEY=""

  # Mock git: fail local, succeed global (FAKE)
  git() {
    if [ "$1" = "config" ] && [ "$2" = "--local" ]; then
      return 1
    elif [ "$1" = "config" ] && [ "$2" = "--global" ]; then
      echo "EEEEFFFF00001111"
      return 0
    fi
    return 1
  }

  resolve_sign_key
  _assert_equals "0" "$?" "Should resolve key from git config --global"
  _assert_equals "EEEEFFFF00001111" "$SIGN_KEY" "Should set SIGN_KEY from git global"
}

test_resolve_sign_key_fail_missing_key() {
  SIGN_KEY=""
  local _ret=0

  # Mock git to return nothing
  git() { return 1; }

  # Capture output to avoid polluting test logs
  (resolve_sign_key >/dev/null 2>&1) || _ret=$?
  _assert_equals "1" "$_ret" "Should fail when no key is found anywhere"
}

test_resolve_sign_key_fail_gpg_keyring_missing() {
  # FAKE TEST KEY — safe to expose
  # gitleaks:allow
  SIGN_KEY="1234567890ABCDEF"
  local _ret=0

  # Mock gpg to fail list-keys.
  # Note: gpg_wrapper calls gpg.
  # We need to make the underlying gpg mock fail.
  # shellcheck disable=SC2317
  gpg() { return 1; }

  (resolve_sign_key >/dev/null 2>&1) || _ret=$?
  _assert_equals "1" "$_ret" "Should fail if key exists but is not in GPG keyring"
}

######################################################################
# Tests for gpg_wrapper
######################################################################

test_gpg_wrapper_no_homedir() {
  GPG_HOME=""
  local _out
  # Need to reset gpg mock for this test to behave normally
  gpg() {
    if [ "$1" = "--homedir" ]; then
      echo "GPG_CALLED_WITH_HOMEDIR=$2"
    fi
    return 0
  }

  _out="$(gpg_wrapper --list-keys)"

  # Ensure --homedir was NOT passed (mock echoes nothing related to homedir)
  if echo "$_out" | grep -q "GPG_CALLED_WITH_HOMEDIR"; then
    echo "Fail: gpg_wrapper passed homedir when variable was empty"
    exit 1
  fi
}

test_gpg_wrapper_with_homedir() {
  GPG_HOME="/tmp/custom-gpg"
  local _out

  gpg() {
    if [ "$1" = "--homedir" ]; then
      echo "GPG_CALLED_WITH_HOMEDIR=$2"
    fi
    return 0
  }

  _out="$(gpg_wrapper --list-keys)"

  # Ensure mock received the homedir arg
  if ! echo "$_out" | grep -q "GPG_CALLED_WITH_HOMEDIR=/tmp/custom-gpg"; then
    echo "Fail: gpg_wrapper did not pass correct homedir"
    echo "Output was: $_out"
    exit 1
  fi
}

######################################################################
# Tests for Argument Parsing (GPG Home)
######################################################################

test_parse_args_gpg_home() {
  # Reset
  GPG_HOME=""

  # Call parse_args with the flag
  parse_args --gpg-home "/var/secure/gpg"

  _assert_equals "/var/secure/gpg" "$GPG_HOME" "Should parse --gpg-home correctly"
}

test_parse_args_gpg_home_env_fallback() {
  # Set env var
  export GNUPGHOME="/env/path/gpg"

  # Call parse_args without flag
  parse_args --sign

  _assert_equals "/env/path/gpg" "$GPG_HOME" "Should default to GNUPGHOME env var"
}

test_parse_args_gpg_home_override() {
  export GNUPGHOME="/env/path/gpg"

  # Flag should override env var
  parse_args --gpg-home "/override/path"

  _assert_equals "/override/path" "$GPG_HOME" "Flag should override GNUPGHOME env var"
}
