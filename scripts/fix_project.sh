#!/bin/sh
#
# fix_project.sh - Automatic project correction tool.
#
# This script applies automatic fixes for formatting and other common issues.
#
# shellcheck disable=SC3043 # In POSIX sh, local is undefined but supported.

set -eu

# Path to the main script to source utilities
TARGET_SCRIPT="src/letsgolang.sh"

if [ ! -f "$TARGET_SCRIPT" ]; then
  printf "Error: Main script not found at %s\n" "$TARGET_SCRIPT" >&2
  exit 1
fi

# Source the script to get access to logging/utility functions.
export SOURCED_FOR_TESTING=true
# shellcheck source=/dev/null
. "./$TARGET_SCRIPT"

######################################################################
# Fix Functions
######################################################################

# fix_code_formatting: Applies automatic formatting using shfmt.
fix_code_formatting() {
  local _funcname='fix_code_formatting'
  local _dirs="src scripts test"

  if ! command -v shfmt >/dev/null 2>&1; then
    log_warn "$_funcname" "shfmt not found. Cannot apply automatic formatting."
    return 1
  fi

  log_info "$_funcname" "Applying automatic formatting with shfmt..."

  # shellcheck disable=SC2086
  if shfmt -w -i 2 -ci -bn $_dirs; then
    log_success "$_funcname" "Code formatting applied successfully."
  else
    log_error "$_funcname" "Failed to apply code formatting."
    return 1
  fi
}

######################################################################
# Main Function
######################################################################

main() {
  local _funcname='main'

  log_info "$_funcname" "Starting automatic project fixes..."

  local _failed=0

  # 1. Apply code formatting
  fix_code_formatting || _failed=1

  if [ "$_failed" -eq 0 ]; then
    log_success "$_funcname" "All automatic fixes applied successfully."
  else
    log_warn "$_funcname" "Some fixes could not be applied automatically."
    exit 1
  fi
}

main "$@"
