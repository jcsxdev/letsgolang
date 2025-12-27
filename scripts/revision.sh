#!/bin/sh
#
# revision.sh - Version and metadata synchronization tool.
#
# This script synchronizes version constants (version, commit hash, and date)
# within a target shell script based on the current Git repository state.
# It leverages functions from the target script for logging and utilities.
#
# shellcheck disable=SC3043 # In POSIX sh, local is undefined but widely supported.

set -u

# Guard variable to prevent sourced scripts from executing their main routine.
export SOURCED_FOR_TESTING=true

######################################################################
# Core Logic Functions
######################################################################

# get_git_version: Retrieves the latest tag from Git or defaults to '0.0.0'.
# Output: Version string (e.g., 1.2.3 or 0.0.0 as fallback).
get_git_version() {
  local _git_tag
  # Try to get the closest tag. If no tags exist, default to 0.0.0.
  if _git_tag=$(git describe --tags --abbrev=0 2>/dev/null); then
    printf "%s" "$_git_tag" | sed 's/^v//'
  else
    printf "0.0.0"
  fi
}

# get_git_commit: Retrieves the current short commit hash.
# Output: Short commit hash (e.g., 1766dbb).
get_git_commit() {
  # Get the short commit hash
  git rev-parse --short HEAD
}

# get_current_date: Retrieves the current date in UTC format.
# Output: Date string (YYYY-MM-DD).
get_current_date() {
  # Get the current date in UTC format
  date -u +'%Y-%m-%d'
}

# validate_target_file: Ensures the target file has the required metadata markers.
# Arguments: <target_file_path>
# Returns: 0 on success, 1 if markers are missing.
validate_target_file() {
  local _funcname='validate_target_file'
  local _target_file="${1-}"

  # Ensure the target file contains the necessary versioning and commit information
  if ! grep -q "G_SCRIPT_COMMIT=" "$_target_file"; then
    log_error "$_funcname" "Validation failed: '$_target_file' is missing 'G_SCRIPT_COMMIT'."
    return 1
  fi
  if ! grep -q "G_SCRIPT_DATE=" "$_target_file"; then
    log_error "$_funcname" "Validation failed: '$_target_file' is missing 'G_SCRIPT_DATE'."
    return 1
  fi
  log_info "$_funcname" "Target file '$_target_file' passed validation."
  return 0
}

# update_file_content: Performs the actual string replacement in the target file.
# Arguments: <target_file> <version> <commit> <date>
# Returns: 0 on success, 1 on I/O or permission error.
# update_file_content: Performs the actual string replacement in the target file.
# Arguments: <target_file> <version> <commit> <date>
# Returns: 0 on success, 1 on I/O or permission error.
update_file_content() {
  local _funcname='update_file_content'
  local _target_file="$1"
  local _new_version="$2"
  local _new_commit="$3"
  local _new_date="$4"

  local _temp_file
  # Use the helper function from the sourced script. The cleanup is handled
  # by the trap set in the sourced script's main function.
  _temp_file=$(get_temporary_file) || return 1

  # Get original permissions to restore them later
  local _original_permissions
  _original_permissions=$(stat -c "%a" "$_target_file" 2>/dev/null || stat -f "%Lp" "$_target_file") || return 1

  log_info "$_funcname" "Updating '$_target_file'..."

  # Use a sed regex that handles:
  # - G_SCRIPT_VERSION='1.2.3'
  # - G_SCRIPT_VERSION=
  # - G_SCRIPT_VERSION=""
  # The regex looks for the variable name and replaces the entire assignment.
  sed -e "s|G_SCRIPT_VERSION=.*|G_SCRIPT_VERSION='$_new_version'|; \
          s|G_SCRIPT_COMMIT=.*|G_SCRIPT_COMMIT='$_new_commit'|; \
          s|G_SCRIPT_DATE=.*|G_SCRIPT_DATE='$_new_date'|" \
    "$_target_file" >"$_temp_file" && mv "$_temp_file" "$_target_file"

  # Restore original permissions
  chmod "$_original_permissions" "$_target_file" || return 1
}

######################################################################
# Process Revision Routine
######################################################################

# process_revision_routine: Orchestrates the metadata synchronization process.
# Arguments: <target_file>
# Returns: 0 on success, 1 on error.
process_revision_routine() {
  local _funcname='process_revision_routine'
  local _target_file="${1-}" # Passed from main

  # Full validation can happen here because the file has been sourced.
  if ! validate_target_file "$_target_file"; then
    return 1
  fi

  local _new_version _new_commit _new_date
  _new_version=$(get_git_version) || { log_error "$_funcname" "Could not get version from Git." && return 1; }
  _new_commit=$(get_git_commit) || { log_error "$_funcname" "Could not get commit hash." && return 1; }
  _new_date=$(get_current_date) || { log_error "$_funcname" "Could not get current date." && return 1; }

  if [ -z "$_new_version" ]; then
    log_error "$_funcname" "Could not get a valid version from Git. Is this a git repository?"
    return 1
  fi

  log_info "$_funcname" "Syncing to Git version: $(set_text bold "$_new_version")"

  if ! update_file_content "$_target_file" "$_new_version" "$_new_commit" "$_new_date"; then
    log_error "$_funcname" "Failed to update file content."
    return 1
  fi

  log_success "$_funcname" "Update complete."
  return 0
}

######################################################################
# Main Function
######################################################################

# main: Entry point for the revision script.
# Arguments: <path_to_script>
# Returns: 0 on success, 1 on invalid arguments or execution error.
main() {
  local _funcname='main'
  set -e # Enable exit on error within main

  local _target_file="${1-}"
  if [ -z "$_target_file" ]; then
    printf "\033[31mError: %s\033[0m\n" "Usage: ./scripts/revision.sh <path_to_script>" >&2
    return 1
  fi

  if [ ! -f "$_target_file" ]; then
    printf "\033[31mError: %s\033[0m\n" "Target file not found at '$_target_file'." >&2
    return 1
  fi

  # PRE-VALIDATION: Before sourcing the file, do a basic check to ensure it's not
  # completely invalid. This prevents the script from executing arbitrary code.
  if ! grep -q "G_SCRIPT_VERSION=" "$_target_file"; then
    printf "\033[31mError: %s\033[0m\n" "Validation failed: '$_target_file' is missing 'G_SCRIPT_VERSION'. Cannot proceed." >&2
    return 1
  fi

  # Source the target script to get access to its functions (e.g., logging, cleanup)
  # The guard at the end of the sourced script prevents it from running its own main()
  # shellcheck source=/dev/null
  . "$_target_file"

  # Setup traps after sourcing, so set_trap is available.
  trap '{ set_trap abort; }' TERM INT
  # The EXIT trap is now inherited from the sourced script, which will call trap_cleanup.

  # Now call the actual logic
  process_revision_routine "$_target_file" || return 1

  return 0
}

main "$@" || exit
