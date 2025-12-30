#!/bin/sh
#
# check_project.sh - Project integrity and metadata validator.
#
# This script performs a series of checks to ensure the repository state
# is consistent and ready for release. It validates that version constants
# are populated and synchronized with Git metadata.
#
# shellcheck disable=SC3043 # In POSIX sh, local is undefined but supported.

set -u

# Guard to prevent sourced scripts from executing main.
export SOURCED_FOR_TESTING=true

######################################################################
# Core Integrity Checks
######################################################################

# check_constants_populated: Ensures version markers are not empty.
# Arguments: <target_file>
# Returns: 0 if all constants have values, 1 otherwise.
check_constants_populated() {
  local _funcname='check_constants_populated'
  local _target="$1"
  local _fail=0

  for _var in G_SCRIPT_VERSION G_SCRIPT_COMMIT G_SCRIPT_DATE; do
    # Extract value using sed (handles single or double quotes)
    local _val
    _val=$(grep "$_var=" "$_target" | cut -d'=' -f2 | tr -d "'\" ")

    if [ -z "$_val" ] || [ "$_val" = "0.0.0" ] && [ "$_var" != "G_SCRIPT_VERSION" ]; then
      log_error "$_funcname" "Metadata marker [$_var] is empty or default in $_target."
      _fail=1
    fi
  done

  return $_fail
}

# check_version_alignment: Ensures script version matches Git state.
# Arguments: <target_file>
# Returns: 0 if aligned, 1 if mismatch.
check_version_alignment() {
  local _funcname='check_version_alignment'
  local _target="$1"

  local _script_v=
  _script_v=$(grep "G_SCRIPT_VERSION=" "$_target" | cut -d'=' -f2 | tr -d "'\" ")

  local _git_v=
  local _git_v_cmd=
  # Use logic from revision.sh: get tag or fallback to 0.0.0
  _git_v_cmd=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')
  if [ -n "$_git_v_cmd" ]; then
    _git_v="$_git_v_cmd"
  else
    _git_v="0.0.0"
  fi

  if [ "$_script_v" != "$_git_v" ]; then
    log_error "$_funcname" "Version mismatch! Git: '$_git_v' vs Script: '$_script_v'"
    return 1
  fi

  log_info "$_funcname" "Version alignment verified: '$_script_v'"
  return 0
}

# check_shell_quality: Runs ShellCheck on project scripts.
# Returns: 0 if all scripts pass, 1 otherwise.
check_shell_quality() {
  local _funcname='check_shell_quality'
  local _scripts="src/*.sh scripts/*.sh test/*.sh"
  local _fail=0

  if ! command -v shellcheck >/dev/null 2>&1; then
    log_warn "$_funcname" "ShellCheck not found. Skipping quality check."
    return 0
  fi

  log_info "$_funcname" "Running ShellCheck validation..."

  for _file in $_scripts; do
    [ -f "$_file" ] || continue
    if ! cat "$_file" | shellcheck -x -e SC1091 -e SC2034 -; then
      log_error "$_funcname" "ShellCheck failed for: $_file"
      _fail=1
    fi
  done

  if [ "$_fail" -eq 0 ]; then
    log_info "$_funcname" "ShellCheck validation passed."
    return 0
  fi

  return 1
}

######################################################################
# Main Function
######################################################################

# main: Orchestrates the project verification routine.
main() {
  local _funcname='main'
  local _target_script="src/letsgolang.sh"
  local _exit_status=0

  if [ ! -f "$_target_script" ]; then
    printf "Error: Main script not found at %s\n" "$_target_script" >&2
    return 1
  fi

  # Source the script to get access to logging/utility functions.
  # shellcheck source=/dev/null
  . "./$_target_script"

  log_info "$_funcname" "Starting project integrity checks..."

  # 1. Check if version constants are populated
  if ! check_constants_populated "$_target_script"; then
    _exit_status=1
  fi

  # 2. Check for version alignment with Git
  if ! check_version_alignment "$_target_script"; then
    _exit_status=1
  fi

  # 3. Check shell script quality with ShellCheck
  if ! check_shell_quality; then
    _exit_status=1
  fi

  if [ "$_exit_status" -eq 0 ]; then
    log_success "$_funcname" "Project integrity verified successfully. ✨"
  else
    log_error "$_funcname" "Project integrity checks failed. Run 'make bump-version' to fix metadata."
  fi

  return $_exit_status
}

main "$@" || exit
