#!/bin/sh

# test_json_verification.sh - Tests for JSON checksum verification logic.
#
# This script verifies the parsing and verification logic for the JSON API
# integration, ensuring it correctly handles both valid and invalid scenarios.
#
# shellcheck disable=SC3043 # In POSIX sh, local is undefined but supported by many shells.
# shellcheck disable=SC2329 # Mocks are called by sourced functions

fail() {
  printf "FAIL: %s\n" "$1"
  return 1
}

test_json_url_getter() {
  local _url
  _url=$(get_json_checksum_url)
  _assert_equals "https://go.dev/dl/?mode=json" "$_url" "URL should match expected value"
}

test_json_checksum_extraction_success() {
  # Mock run_curl to return a sample JSON response
  run_curl() {
    cat <<EOF
[
 {
  "version": "go1.25.6",
  "stable": true,
  "files": [
   {
    "filename": "go1.25.6.linux-amd64.tar.gz",
    "os": "linux",
    "arch": "amd64",
    "version": "go1.25.6",
    "sha256": "f022b6aad78e362bcba9b0b94d09ad58c5a70c6ba3b7582905fababf5fe0181a",
    "size": 59768880,
    "kind": "archive"
   }
  ]
 }
]
EOF
    return 0
  }

  local _checksum
  _checksum=$(get_remote_checksum_from_json --filename "go1.25.6.linux-amd64.tar.gz" --version "go1.25.6")
  _assert_equals "f022b6aad78e362bcba9b0b94d09ad58c5a70c6ba3b7582905fababf5fe0181a" "$_checksum" "Checksum should match JSON value"
}

test_json_checksum_extraction_multiple_versions() {
  # Mock run_curl with multiple versions and files
  run_curl() {
    cat <<EOF
[
 {
  "version": "go1.25.6",
  "files": [
   {
    "filename": "go1.25.6.linux-amd64.tar.gz",
    "sha256": "correct_hash_123"
   },
   {
    "filename": "go1.25.6.windows-amd64.zip",
    "sha256": "other_hash_456"
   }
  ]
 },
 {
  "version": "go1.24.0",
  "files": [
   {
    "filename": "go1.24.0.linux-amd64.tar.gz",
    "sha256": "old_hash_789"
   }
  ]
 }
]
EOF
    return 0
  }

  local _checksum
  _checksum=$(get_remote_checksum_from_json --filename "go1.25.6.linux-amd64.tar.gz" --version "go1.25.6")
  _assert_equals "correct_hash_123" "$_checksum" "Should extract correct hash from multiple items"
}

test_json_checksum_extraction_reordered_fields() {
  # Mock run_curl where 'filename' comes AFTER 'sha256' or other fields
  # This tests robustness against field ordering and neighbor interference
  run_curl() {
    # Minified JSON with reordered fields and a decoy file
    printf '[{"files":[{"sha256":"BAD_HASH","filename":"decoy.tar.gz"},{"os":"linux","sha256":"GOOD_HASH","filename":"target.tar.gz"}]}]'
    return 0
  }

  local _checksum
  _checksum=$(get_remote_checksum_from_json --filename "target.tar.gz")
  _assert_equals "GOOD_HASH" "$_checksum" "Should handle reordered JSON fields and ignore decoys"
}

test_json_checksum_extraction_not_found() {
  # Mock run_curl to return a sample JSON response
  run_curl() {
    cat <<EOF
[
 {
  "version": "go1.25.6",
  "files": []
 }
]
EOF
    return 0
  }

  if get_remote_checksum_from_json --filename "nonexistent.tar.gz" >/dev/null 2>&1; then
    fail "Should have failed to find checksum for nonexistent file"
  fi
}

test_json_checksum_extraction_curl_fail() {
  # Mock run_curl to simulate failure
  run_curl() {
    return 1
  }

  if get_remote_checksum_from_json --filename "go1.25.6.linux-amd64.tar.gz" >/dev/null 2>&1; then
    fail "Should have failed when curl fails"
  fi
}

# Load the assertion library
# shellcheck disable=SC1091
. ./test/assert.sh

# Load the script under test
# shellcheck disable=SC1091
. ./src/letsgolang.sh
