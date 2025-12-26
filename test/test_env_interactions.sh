#!/bin/sh
#
# test_env_interactions.sh - Unit tests for letsgolang.sh environment interactions.
#
# This script validates functions that interact with the filesystem, network,
# or system environment, such as checksumming and architecture detection.
#
# shellcheck disable=SC3043 # In POSIX sh, local is undefined but widely supported.

set -u

export SOURCED_FOR_TESTING=true

# -- Setup --

# shellcheck disable=SC1091 # Not following.
. ./src/letsgolang.sh
# shellcheck disable=SC1091 # Not following.
. ./test/assert.sh

######################################################################
# Test Cases
######################################################################

# test_get_checksum: Validates the file checksum calculation logic.
test_get_checksum() {
  local _temp_file
  _temp_file=$(get_temporary_file)
  printf "hello world" >"$_temp_file"

  local _expected_sha256="b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9"
  local _expected_sha512="309ecc489c12d6eb4cc40f50c902f2b4d0ed77ee511a7c7a9bcd3ca86d4cd86f989dd35bc5ff499670da34255b45b0cfd830e81f605dcf7dc5542e93ae9cd76f"

  # Test sha256
  local _result_sha256
  _result_sha256=$(get_checksum sha256 --file "$_temp_file")
  _assert_equals "$_expected_sha256" "$_result_sha256" "Should get correct sha256 checksum."

  # Test sha512
  local _result_sha512
  _result_sha512=$(get_checksum sha512 --file "$_temp_file")
  _assert_equals "$_expected_sha512" "$_result_sha512" "Should get correct sha512 checksum."

  rm "$_temp_file"
}

# test_get_file_permission: Validates the retrieval of octal file permissions.
test_get_file_permission() {
  local _temp_file
  _temp_file=$(get_temporary_file)

  chmod 755 "$_temp_file"
  local _result
  _result=$(get_file_permission "$_temp_file")
  _assert_equals "755" "$_result" "Should correctly get 755 permission."

  chmod 644 "$_temp_file"
  _result=$(get_file_permission "$_temp_file")
  _assert_equals "644" "$_result" "Should correctly get 644 permission."

  chmod 600 "$_temp_file"
  _result=$(get_file_permission "$_temp_file")
  _assert_equals "600" "$_result" "Should correctly get 600 permission."

  rm "$_temp_file"
}

# test_get_total_lines_num: Validates the line counting utility.
test_get_total_lines_num() {
  local _temp_file
  _temp_file=$(get_temporary_file)

  printf "line 1\nline 2\nline 3\n" >"$_temp_file"
  local _result
  _result=$(get_total_lines_num --file "$_temp_file")
  _assert_equals "3" "$_result" "Should correctly get 3 lines."

  printf "one line\n" >"$_temp_file"
  _result=$(get_total_lines_num --file "$_temp_file")
  _assert_equals "1" "$_result" "Should correctly get 1 line."

  : >"$_temp_file" # Empty file
  _result=$(get_total_lines_num --file "$_temp_file")
  _assert_equals "0" "$_result" "Should correctly get 0 for an empty file."

  rm "$_temp_file"
}

# test_is_architectures: Validates architecture-specific predicates using mocks.
test_is_architectures() {
  # Mock architecture for amd64 test
  # shellcheck disable=SC2329 # This function is never invoked. Check usage (or ignored if invoked indirectly).
  get_machine_architecture() {
    printf "x86_64"
  }

  is_amd64_architecture
  _assert_equals "0" "$?" "is_amd64_architecture should return 0 for x86_64."
  is_386_architecture
  _assert_equals "1" "$?" "is_386_architecture should return 1 for x86_64."

  # Mock architecture for 386 test
  # shellcheck disable=SC2329 # This function is never invoked. Check usage (or ignored if invoked indirectly).
  get_machine_architecture() {
    printf "i686"
  }
  is_386_architecture
  _assert_equals "0" "$?" "is_386_architecture should return 0 for i686."
  is_amd64_architecture
  _assert_equals "1" "$?" "is_amd64_architecture should return 1 for i686."

  unset -f get_machine_architecture
}

# test_is_go_command_found: Validates the Go binary discovery logic in PATH.
test_is_go_command_found() {
  local _original_path="$PATH"
  local _temp_dir
  _temp_dir=$(get_temporary_dir)

  touch "$_temp_dir/go"
  chmod +x "$_temp_dir/go"

  # Case: Go is in PATH
  export PATH="$_temp_dir:$PATH"
  is_go_command_found
  _assert_equals "0" "$?" "is_go_command_found should return 0 when go is in PATH."

  # Case: Go is NOT in PATH
  export PATH="/some/other/dir"
  is_go_command_found
  _assert_equals "1" "$?" "is_go_command_found should return 1 when go is not in PATH."

  /bin/rm -r "$_temp_dir"
  export PATH="$_original_path"
}
