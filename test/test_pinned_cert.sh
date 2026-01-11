#!/bin/sh
#
# test_pinned_cert.sh - Unit tests for certificate pinning functionality.
#
# shellcheck disable=SC3043 # In POSIX sh, local is undefined but widely supported.
# shellcheck disable=SC2329 # Tests are invoked dynamically runner.

set -u
export SOURCED_FOR_TESTING=true

# Source the script and assertion library
# We need to handle the case where we are running from root or from test/
if [ -f "./src/letsgolang.sh" ]; then
  # shellcheck disable=SC1091
  . "./src/letsgolang.sh"
else
  # shellcheck disable=SC1091
  . "../src/letsgolang.sh"
fi

if [ -f "./test/assert.sh" ]; then
  # shellcheck disable=SC1091
  . "./test/assert.sh"
else
  # shellcheck disable=SC1091
  . "../test/assert.sh"
fi

# --- Tests ---
test_args_parsing() {
  # Reset globals
  g_pinned_cert=""
  g_cert_fingerprint=""

  # Test parsing
  # gitleaks:allow
  local _valid_fingerprint="sha256//AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
  get_main_opts --pinned-cert "/tmp/ca.pem" --cert-fingerprint "$_valid_fingerprint"

  _assert_equals "/tmp/ca.pem" "$g_pinned_cert" "g_pinned_cert should be set."
  _assert_equals "$_valid_fingerprint" "$g_cert_fingerprint" "g_cert_fingerprint should be set."
}

test_args_validation() {
  # Test missing argument for --pinned-cert
  # We expect get_main_opts to print to stderr and return 1
  if get_main_opts --pinned-cert 2>/dev/null; then
    _assert_equals "failure" "success" "Should fail on missing arg for --pinned-cert"
  fi

  # Test missing argument for --cert-fingerprint
  if get_main_opts --cert-fingerprint 2>/dev/null; then
    _assert_equals "failure" "success" "Should fail on missing arg for --cert-fingerprint"
  fi
}

test_run_curl_pinned_cert() {
  # Mock curl
  # We must ensure this mock is used. run_curl invokes 'curl'.
  # Since run_tests.sh runs tests in a subshell, this override is safe.
  curl() {
    echo "$@"
    return 0
  }

  g_pinned_cert="/tmp/ca.pem"
  g_cert_fingerprint=""

  local _output
  _output=$(run_curl "https://example.com")

  _assert_contains "$_output" "--cacert /tmp/ca.pem" "Should use --cacert when g_pinned_cert is set"
  _assert_contains "$_output" "https://example.com" "Should contain the URL"
}

test_run_curl_fingerprint() {
  # Mock curl
  curl() {
    echo "$@"
    return 0
  }

  g_pinned_cert=""
  # gitleaks:allow
  g_cert_fingerprint="SHA256:1234"

  local _output
  _output=$(run_curl "https://example.com")

  _assert_contains "$_output" "--pinnedpubkey SHA256:1234" "Should use --pinnedpubkey when g_cert_fingerprint is set"
}

test_run_curl_both() {
  # Mock curl
  curl() {
    echo "$@"
    return 0
  }

  g_pinned_cert="/tmp/ca.pem"
  # gitleaks:allow
  g_cert_fingerprint="SHA256:1234"

  local _output
  _output=$(run_curl "https://example.com")

  _assert_contains "$_output" "--cacert /tmp/ca.pem" "Should use --cacert when both are set"
  _assert_contains "$_output" "--pinnedpubkey SHA256:1234" "Should use --pinnedpubkey when both are set"
}

test_run_curl_none() {
  # Mock curl
  curl() {
    echo "$@"
    return 0
  }

  g_pinned_cert=""
  g_cert_fingerprint=""

  local _output
  _output=$(run_curl "https://example.com")

  # Check that pinning flags are NOT present
  # _assert_not_contains is not defined in typical assert.sh, so we check manually
  if echo "$_output" | grep -q -- "--cacert"; then
    _assert_equals "no-cacert" "cacert" "Should NOT use --cacert by default"
  fi
  if echo "$_output" | grep -q -- "--pinnedpubkey"; then
    _assert_equals "no-pinnedpubkey" "pinnedpubkey" "Should NOT use --pinnedpubkey by default"
  fi
}

test_validation_missing_file() {
  g_pinned_cert="/non/existent/file.pem"
  g_cert_fingerprint=""

  # Run in subshell to capture exit code if it exits, but validate_pinning_config returns 1
  if validate_pinning_config 2>/dev/null; then
    _assert_equals "failure" "success" "Should fail on missing file"
  fi
}

test_validation_curl_version_old() {
  g_pinned_cert=""
  # gitleaks:allow
  g_cert_fingerprint="sha256//valid"

  # Mock curl to return old version
  curl() {
    if [ "$1" = "-V" ]; then
      echo "curl 7.38.0 (x86_64-pc-linux-gnu)..."
    fi
  }

  if validate_pinning_config 2>/dev/null; then
    _assert_equals "failure" "success" "Should fail on old curl version"
  fi
  unset curl
}

test_validation_curl_version_ok() {
  g_pinned_cert=""
  # gitleaks:allow
  g_cert_fingerprint="sha256//valid"

  # Mock curl to return ok version
  curl() {
    if [ "$1" = "-V" ]; then
      echo "curl 7.39.0 (x86_64-pc-linux-gnu)..."
    fi
  }

  if ! validate_pinning_config 2>/dev/null; then
    _assert_equals "success" "failure" "Should pass on ok curl version"
  fi
  unset curl
}

test_validation_fingerprint_invalid_format() {
  g_pinned_cert=""
  # gitleaks:allow
  g_cert_fingerprint="INVALID:FORMAT"

  if validate_pinning_config 2>/dev/null; then
    _assert_equals "failure" "success" "Should fail on invalid fingerprint format"
  fi
}
