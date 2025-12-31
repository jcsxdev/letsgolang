#!/bin/sh
#
# letsgolang.sh - A robust, POSIX-compliant Go language installer.
#
# This script automates the process of downloading, verifying, and performing a
# non-root installation of the Go programming language on Linux systems.
# It handles architecture detection, checksum verification, and environment
# configuration.
#
# shellcheck disable=SC3043 # In POSIX sh, local is undefined but supported by many shells.

set -u

######################################################################
# Global variables
######################################################################

# VERSION BLOCK (managed by scripts/revision.sh)
# These constants are updated automatically during the release process.
readonly G_SCRIPT_VERSION='0.1.0'
readonly G_SCRIPT_COMMIT='d7297bf'
readonly G_SCRIPT_DATE='2025-12-27'
# END VERSION BLOCK

# SETTINGS BLOCK
# Global state flags determined by command-line arguments.
g_need_tty=yes      # Whether a TTY is available for interactive prompts
g_quiet_mode=no     # If yes, suppress non-essential output
g_uninstall_mode=no # If yes, run the uninstallation routine
g_verbose_mode=no   # If yes, provide detailed execution logs
# END SETTINGS BLOCK

# GENERAL BLOCK
# Variables populated during execution to track installation state.
g_installation_filename= # Name of the downloaded tarball
g_remote_version_str=    # Raw version string from Go server (e.g., go1.21.0)
g_remote_version=        # Cleaned version string (e.g., 1.21.0)
g_reload_command=        # Instruction to reload the shell profile
g_total_execution_steps= # Total number of steps in the routine
# END GENERAL BLOCK

######################################################################
# Main functions
######################################################################

# usage: Displays the help message to stdout.
# Returns: 0 always.
usage() {
  cat <<EOF
$(get_script_version)

The non-root installer for Go programming language

Usage: $(get_script_name)[EXE] [OPTIONS]

Options:
  -u, --uninstall, --remove
          Uninstall Go (removes binary and environment configuration)
  -v, --verbose
          Enable verbose mode
  -q, --quiet
          Enable quiet mode (suppress non-essential output)
  -y, --assume-yes
          Run in non-interactive mode (assume yes to all prompts)
  -h, --help
          Print help
  -V, --version
          Print version
EOF

  return 0
}

# main: The entry point of the script. Sets up traps and initiates the routine.
# Arguments: Command-line arguments.
# Returns: 0 on success, 1 on error.
main() {
  set -e
  trap '{ set_trap abort; }' TERM INT
  trap '{ set_trap cleanup; }' EXIT

  get_main_opts "$@" || return 1

  # Auto-detect TTY: If not running in an interactive terminal,
  # force non-interactive mode to avoid errors with /dev/tty.
  if [ ! -t 1 ]; then
    g_need_tty=no
  fi

  if [ "$g_uninstall_mode" = "yes" ]; then
    process_uninstall_routine || return 1
  else
    process_main_routine || return 1
  fi

  return 0
}

# process_main_routine: Orchestrates the step-by-step execution of the installer.
# This function dynamically retrieves the list of steps and executes them in sequence.
# Returns: 0 on success, 1 on error.
process_main_routine() {
  local _funcname='process_main_routine'

  local _execution_step=
  local _steps_list=
  local _temp_dir=
  local _status_message=
  local _step_count=

  if _status_message=$(get_execution_step --list 2>&1); then
    _steps_list=$_status_message
  else
    if [ -n "$_status_message" ]; then
      log_error "$_funcname" "$_status_message"
    else
      log_error "$_funcname" "Internal: failed to get steps list."
    fi

    return 1
  fi

  _status_message=

  if _status_message=$(get_temporary_dir 2>&1); then
    _temp_dir="$_status_message"
  else
    if [ -n "$_status_message" ]; then
      log_error "$_funcname" "$(cat "$_status_message")"
    else
      log_error "$_funcname" "Internal: failed to get temporary dir."
    fi

    return 1
  fi

  _status_message=

  if _status_message=$(get_execution_step --list-length 2>&1); then
    g_total_execution_steps=$_status_message
  else
    if [ -n "$_status_message" ]; then
      printf '%b\n' "$_status_message"
    else
      log_error "$_funcname" "Internal: failed to get execution steps list length."
    fi

    return 1
  fi

  for _execution_step in $_steps_list; do
    case $_execution_step in
      STEP1)
        _step_count=$((_step_count + 1))
        process_step1 || return 1
        ;;
      STEP2)
        _step_count=$((_step_count + 1))
        process_step2
        local _step2_status=$?
        if [ $_step2_status -eq 99 ]; then
          [ -d "$_temp_dir" ] && rm -r "$_temp_dir"
          return 0
        elif [ $_step2_status -ne 0 ]; then
          return 1
        fi
        ;;
      STEP3)
        _step_count=$((_step_count + 1))
        process_step3 --temp-dir "$_temp_dir" || return 1
        ;;
      STEP4)
        _step_count=$((_step_count + 1))
        process_step4 || return 1
        ;;
      STEP5)
        _step_count=$((_step_count + 1))
        process_step5 --temp-dir "$_temp_dir" || return 1
        ;;
      STEP6)
        _step_count=$((_step_count + 1))
        process_step6 --temp-dir "$_temp_dir" || return 1
        ;;
      *)
        log_error "$_funcname" \
          "Internal: invalid execution step name: '$_execution_step'."

        return 1
        ;;
    esac
  done

  [ -d "$_temp_dir" ] && rm -r "$_temp_dir"

  if [ $_step_count -eq "$g_total_execution_steps" ]; then
    log_info "$_funcname" "Done."

    if [ -n "$g_reload_command" ]; then
      printf "\n%s\n" "$(set_text bold "To apply the changes to your current shell session, run:")"
      printf "  %s\n\n" "$(set_text green "$g_reload_command")"
    fi

    return 0
  fi

  return 0
}

# process_uninstall_routine: Removes Go installation and environment configuration.
# Returns: 0 on success, 1 on error.
process_uninstall_routine() {
  local _funcname='process_uninstall_routine'
  local _go_dir=
  local _profile_file=

  _go_dir="$(get_go_dir)"

  log_info "$_funcname" "Starting uninstallation..."

  if [ -d "$_go_dir" ]; then
    log_info "$_funcname" "Found Go installation at '$_go_dir'."
    if [ "$g_need_tty" = "yes" ]; then
      printf "This action will remove the Go installation from your system.\n"
      printf "Are you sure you want to proceed? Please type 'yes' to confirm: "
      read -r _confirmation
      if [ "$_confirmation" != "yes" ]; then
        log_info "$_funcname" "Uninstallation aborted."
        return 0
      fi
    fi

    if rm -rf "$_go_dir"; then
      log_success "$_funcname" "Removed installation directory."
    else
      log_error "$_funcname" "Failed to remove '$_go_dir'."
      return 1
    fi
  else
    log_warn "$_funcname" "Go installation directory '$_go_dir' not found."
  fi

  # Identifies the active shell environment to locate the corresponding initialization profile.
  case "$SHELL" in
    */bash)
      if [ -f "$HOME/.bash_profile" ]; then
        _profile_file="$HOME/.bash_profile"
      else
        _profile_file="$HOME/.bashrc"
      fi
      ;;
    */zsh) _profile_file="$HOME/.zshrc" ;;
    */fish) _profile_file="$HOME/.config/fish/config.fish" ;;
    */nushell) _profile_file="$HOME/.config/nushell/config.toml" ;;
    *) _profile_file="$HOME/.profile" ;;
  esac

  if [ -f "$_profile_file" ]; then
    log_info "$_funcname" "Checking profile '$_profile_file' for Go environment variables..."

    # Simple grep check to see if we should advise the user
    if grep -q "go/bin" "$_profile_file"; then
      log_warn "$_funcname" "Go related paths were found in '$_profile_file'."
      log_info "$_funcname" \
        "Please manually edit '$_profile_file' to remove GOROOT and PATH exports if they are no longer needed."
    else
      log_info "$_funcname" "No obvious Go paths found in '$_profile_file'."
    fi
  fi

  log_success "$_funcname" "Uninstallation complete."
  return 0
}

######################################################################
#  Predicate Functions
######################################################################

# is_386_architecture: Checks if the system architecture is 32-bit x86.
# Returns: 0 if 386, 1 otherwise.
is_386_architecture() {
  case "$(get_machine_architecture)" in
    i386 | i486 | i586 | i686)
      # Nothing to do here
      ;;
    *)
      return 1
      ;;
  esac

  return 0
}

# is_amd64_architecture: Checks if the system architecture is 64-bit x86.
# Returns: 0 if amd64, 1 otherwise.
is_amd64_architecture() {
  case "$(get_machine_architecture)" in
    x86_64)
      # Nothing to do here
      ;;
    *)
      return 1
      ;;
  esac

  return 0
}

# is_go_command_found: Determines if the 'go' binary is available in the current PATH.
# Returns: 0 if found, 1 otherwise.
is_go_command_found() {
  if ! command -v go >/dev/null 2>&1; then
    return 1
  fi

  return 0
}

# is_no_color: Checks if colored output should be disabled based on environment variables.
# Respects the NO_COLOR standard (https://no-color.org/).
# Returns: 0 if no-color is active, 1 otherwise.
is_no_color() {
  if [ -n "${NO_COLOR:-}" ] \
    && [ "${NO_COLOR:-}" = true ] || [ "${NO_COLOR:-}" = '1' ]; then
    return 0
  fi

  return 1
}

######################################################################
# Process Functions
######################################################################

# process_step1: Retrieves the current remote Go version from the server.
# Populates g_remote_version_str and g_remote_version.
# Returns: 0 on success, 1 on error.
process_step1() {
  local _funcname='process_step1'

  local _status_message=
  local _version_file_url=

  if _status_message=$(get_version_file_url 2>&1); then
    _version_file_url="$_status_message"
  else
    if [ -n "$_status_message" ]; then
      log_error "$_funcname" "$_status_message"
    else
      log_error "$_funcname" "Internal: failed to get version file URL."
    fi

    return 1
  fi

  log_info "$_funcname" \
    "$(set_text bold "STEP 1/$g_total_execution_steps"):"

  log_info "$_funcname" \
    "Getting the current version from '$(set_text bold "$_version_file_url")'..."

  _status_message=

  if [ -z "$g_remote_version_str" ] && _status_message=$(get_remote_go_version_str 2>&1); then
    g_remote_version_str="$_status_message"
    g_remote_version=$(
      printf '%s\n' "$g_remote_version_str" | sed 's/^go//'
    ) || return 1

    log_info "$_funcname" \
      "Current version found: $(set_text bold "$g_remote_version")."
  else
    if [ -n "$_status_message" ]; then
      printf '%b\n' "$_status_message"
    else
      log_error "$_funcname" "Failed to get version."
    fi

    return 1
  fi
}

# process_step2: Searches for an existing Go installation and checks if it's outdated.
# Returns: 99 if the latest version is already installed, 0 to proceed, 1 on error.
process_step2() {
  local _funcname='process_step2'

  log_info "$_funcname" \
    "$(set_text bold "STEP 2/$g_total_execution_steps"):"

  log_info "$_funcname" \
    "Searching for installation..."

  if [ -z "$g_remote_version" ]; then
    log_error "$_funcname" "Internal: 'g_remote_version' global variable is empty."
    return 1
  fi

  if is_go_command_found; then
    local _command_path=
    local _local_version=
    local _status_message=

    if _status_message=$(get_go_command_path 2>&1); then
      _command_path="$_status_message"
    else
      if [ -n "$_status_message" ]; then
        log_error "$_funcname" "$_status_message"
      else
        log_error "$_funcname" "Internal: failed to get command path."
      fi

      return 1
    fi

    _status_message=

    if _status_message=$(get_go_command_version 2>&1); then
      _local_version="$_status_message"
    else
      if [ -n "$_status_message" ]; then
        printf '%b\n' "$_status_message"
      else
        log_error "$_funcname" "Internal: failed to get command version."
      fi

      return 1
    fi

    log_info "$_funcname" \
      "Local installation found: '$_command_path'."

    if [ "$_command_path" != "$(get_go_bin_path)" ]; then
      log_warn "$_funcname" \
        "The binary found is not located in the default ('$(get_go_bin_path)') path."
    fi

    if [ "$g_remote_version" = "$_local_version" ]; then
      log_info "$_funcname" \
        "Nothing to do, you already have the latest Go version."
      return 99
    else
      local _auxiliary_message='versions'
      local _diff_num=

      _status_message=

      if _status_message=$(get_diff_between_versions --v1 "$_local_version" --v2 "$g_remote_version" 2>&1); then
        _diff_num="$_status_message"
      else
        if [ -n "$_status_message" ]; then
          printf '%b\n' "$_status_message"
        else
          log_error "$_funcname" "Internal: failed to get diff betwenn versions."
        fi

        return 1
      fi

      [ "$_diff_num" -eq 1 ] && _auxiliary_message='version'

      log_warn "$_funcname" \
        "The version is outdated: $_diff_num $_auxiliary_message lower than current version."
    fi
  else
    log_info "$_funcname" "No installation found."
  fi
}

# process_step3: Downloads the Go installation file to a temporary directory.
# Arguments: --temp-dir <dir>
# Returns: 0 on success, 1 on error.
process_step3() {
  local _funcname='process_step3'
  local _usage="$_funcname <--temp-dir <dir>>"

  if [ -z "$g_remote_version_str" ]; then
    log_error "$_funcname" "Internal: 'g_remote_version_str' global variable is empty."
    return 1
  fi

  local _architecture_str=
  local _cd_exit_status=
  local _curl_exit_status=
  local _download_server_url=
  local _installation_file_url=
  local _io_tempfile=
  local _status_message=
  local _temp_dir=

  while [ $# -gt 0 ]; do
    case "$1" in
      --temp-dir)
        _temp_dir=$2
        shift
        ;;
      *)
        log_error "$_funcname" \
          "Invalid option ('$1'): usage: $_usage."
        return 1
        ;;
    esac
    shift
  done

  _status_message=

  if _status_message=$(get_temporary_file 2>&1); then
    _io_tempfile="$_status_message"
  else
    if [ -n "$_status_message" ]; then
      log_error "$_funcname" "$(cat "$_status_message")"
    else
      log_error "$_funcname" "Internal: failed to get download server URL."
    fi

    return 1
  fi

  _status_message=

  if _status_message=$(get_machine_architecture_tag 2>&1); then
    _architecture_str="$_status_message"
  else
    if [ -n "$_status_message" ]; then
      printf '%b\n' "$_status_message"
    else
      log_error "$_funcname" "Internal: failed to get machine architecture tag."
    fi

    return 1
  fi

  _status_message=

  if _status_message=$(get_download_server_url 2>&1); then
    _download_server_url="$_status_message"
  else
    if [ -n "$_status_message" ]; then
      printf '%b\n' "$_status_message"
    else
      log_error "$_funcname" "Internal: failed to get download server URL."
    fi

    return 1
  fi

  g_installation_filename="${g_remote_version_str}.linux-${_architecture_str}.tar.gz"
  _installation_file_url="${_download_server_url}/$g_installation_filename"

  log_info "$_funcname" \
    "$(set_text bold "STEP 3/$g_total_execution_steps"):"

  log_info "$_funcname" \
    "Downloading the installation file from '$(set_text bold "$_installation_file_url")'..."

  if [ ! -d "$_temp_dir" ]; then
    log_error "$_funcname" \
      "Is not a directory: '$_temp_dir'."
    return 1
  fi

  cd "$_temp_dir" >"$_io_tempfile" 2>&1

  _cd_exit_status=$?

  if [ "$_cd_exit_status" -ne 0 ]; then
    if [ -s "$_io_tempfile" ]; then
      log_error "$_funcname" "cd (exit: $_cd_exit_status): $(cat "$_io_tempfile")"
    else
      log_error "$_funcname" \
        "cd (exit: $_cd_exit_status): failed to access temporary directory ('$_temp_dir')."
    fi

    return 1
  else
    [ -f "$_io_tempfile" ] && rm "$_io_tempfile"
  fi

  _status_message=

  if ! _status_message=$(get_connection_status --target-url "$_installation_file_url" 2>&1); then
    if [ -n "$_status_message" ]; then
      printf '%b\n' "$_status_message"
    else
      log_error "$_funcname" "Failed to get connection status."
    fi

    return 1
  fi

  run_curl --progress-bar --remote-name --location "${_installation_file_url}"

  _curl_exit_status=$?

  if [ $_curl_exit_status -ne 0 ]; then
    log_error "$_funcname" \
      "curl (exit: $_curl_exit_status): download failed."

    return 1
  fi
}

# process_step4: Validates the checksums of the downloaded file against the remote server.
# Supports SHA-256 and SHA-512 verification.
# Returns: 0 on success, 1 on error.
process_step4() {
  local _funcname='process_step4'

  local _download_server_url=
  local _hash_function=
  local _is_sha256sum_found=false
  local _is_sha512sum_found=false
  local _sha256sum=
  local _sha512sum=
  local _target_checksum=

  log_info "$_funcname" \
    "$(set_text bold "STEP 4/$g_total_execution_steps"):"

  if [ -z "$g_installation_filename" ]; then
    log_error "$_funcname" "Internal: 'g_installation_filename' global variable is empty."
    return 1
  fi

  log_info "$_funcname" \
    "Validating the '$(set_text bold "$g_installation_filename")' file..."

  log_info "$_funcname" \
    "Getting checksums of downloaded files..."

  for _hash_function in SHA-256 SHA-512; do
    local _status_message=
    local _subcommand='sha256'

    [ $_hash_function = 'SHA-512' ] && _subcommand='sha512'

    if _status_message=$(get_checksum "$_subcommand" --file ./"$g_installation_filename" 2>&1); then
      [ $_hash_function = 'SHA-256' ] \
        && _sha256sum=$_status_message \
        || _sha512sum=$_status_message
    else
      if [ -n "$_status_message" ]; then
        log_error "$_funcname" "$_status_message"
      else
        log_error "$_funcname" \
          "Failed to get file checksum ('$_hash_function')."
      fi

      return 1
    fi
  done

  log_info "$_funcname" "File checksums:"
  cat <<EOF
  - SHA256SUM: ${_sha256sum}
  - SHA512SUM: ${_sha512sum}
EOF

  _status_message=

  if _status_message=$(get_download_server_url 2>&1); then
    _download_server_url="$_status_message"
  else
    if [ -n "$_status_message" ]; then
      printf '%b\n' "$_status_message"
    else
      log_error "$_funcname" "Internal: failed to get download server URL."
    fi
    return 1
  fi

  log_info "$_funcname" \
    "Finding checksums on '$_download_server_url'..."

  _status_message=

  if ! _status_message=$(get_connection_status --target-url "$(get_base_url --url "$_download_server_url")" 2>&1); then
    if [ -n "$_status_message" ]; then
      printf '%b\n' "$_status_message"
    else
      log_error "$_funcname" "Failed to get connection status."
    fi

    return 1
  fi

  for _hash_function in SHA-256 SHA-512; do
    _target_checksum="$_sha256sum"

    [ $_hash_function = 'SHA-512' ] && _target_checksum="$_sha512sum"

    if run_curl --silent "${_download_server_url}/" | grep --quiet "$_target_checksum"; then
      [ $_hash_function = 'SHA-256' ] \
        && _is_sha256sum_found=true \
        || _is_sha512sum_found=true
    fi
  done

  local _state=

  # Set bits based on the value of the variables
  [ "$_is_sha256sum_found" = true ] && _state=$((_state | 0x01)) # Set 1st bit (bit 0)
  [ "$_is_sha512sum_found" = true ] && _state=$((_state | 0x02)) # Set 2nd bit (bit 1)

  _state=$(printf "0x%02x" "$_state")

  case "$_state" in
    0x00)
      log_error "$_funcname" \
        "No checksum found."

      return 1
      ;;
    0x01 | 0x10 | 0x011)
      local _checksum_list=
      local _checksum_list_len=
      local _auxiliary_message='checksum'
      local _previous_set=

      [ "$_state" = '0x01' ] && _checksum_list='SHA-256'
      [ "$_state" = '0x10' ] && _checksum_list='SHA-512'
      [ "$_state" = '0x11' ] && _checksum_list='SHA-256 SHA-512'

      [ $# -ge 1 ] && _previous_set="$*"

      # shellcheck disable=SC2086 # Double quote to prevent globbing and word splitting.
      set -- $_checksum_list

      _checksum_list_len="$#"
      [ "$_checksum_list_len" -ge 2 ] && _auxiliary_message='checksums'

      # shellcheck disable=SC2086 # Double quote to prevent globbing and word splitting.
      [ -n "$_previous_set" ] && set -- $_previous_set

      log_info "$_funcname" \
        "$_checksum_list_len $_auxiliary_message found:"

      for _hash_function in $_checksum_list; do
        case "$_hash_function" in
          SHA-256)
            _status_message="SHA256SUM: $_sha256sum"
            ;;
          SHA-512)
            _status_message="SHA512SUM: $_sha512sum"
            ;;
          *)
            return 1
            ;;
        esac

        printf '%s\n' "  - $_status_message"
      done
      ;;
    *)
      log_error "$_funcname" \
        "Unexpected state: '$_state'."

      return 1
      ;;
  esac
}

# process_step5: Extracts the downloaded tarball to the target installation directory.
# Arguments: --temp-dir <dir>
# Returns: 0 on success, 1 on error.
process_step5() {
  local _funcname='process_step5'

  # shellcheck disable=SC2016 # Expressions don't expand in single quotes, use double quotes for that.
  local _bin_path='PATH=$PATH:$HOME/.local/opt/go/bin:$HOME/go/bin'
  local _installation_file=
  local _is_old_dir_removed=false
  local _local_go_dir=
  local _local_opt_dir=
  local _status_code=
  local _status_message=
  local _temp_dir=

  while [ $# -gt 0 ]; do
    case "$1" in
      --temp-dir)
        _temp_dir=$2
        shift
        ;;
      *)
        log_error "$_funcname" \
          "Invalid option ('$1'): usage: $_usage."
        return 1
        ;;
    esac
    shift
  done

  if [ -z "$g_installation_filename" ]; then
    log_error "$_funcname" "Internal: 'g_installation_filename' global variable is empty."
    return 1
  fi

  _installation_file="${_temp_dir}/${g_installation_filename}"
  _local_go_dir="$(get_go_dir)"
  _local_opt_dir=$(get_go_basedir)

  log_info "$_funcname" \
    "$(set_text bold "STEP 5/$g_total_execution_steps"):"

  log_info "$_funcname" \
    "Extracting '$g_installation_filename' file to '$_local_go_dir'..."

  if [ -d "$_local_go_dir" ] && [ -n "$(ls -A "$_local_go_dir")" ]; then
    log_info "$_funcname" "Removing the old '$_local_go_dir' dir..."

    _status_message=$(rm -r "$_local_go_dir" 2>&1)
    _status_code=$?

    if [ "$_status_code" -ne 0 ]; then
      if [ -n "$_status_message" ]; then
        log_error "$_funcname" \
          "rm (exit: $_status_code): failed to remove '$_local_go_dir' dir:"

        cat <<EOF
            
${_status_message}

EOF
      else
        log_error "$_funcname" \
          "rf (exit: $_status_code): failed to remove '$_local_go_dir' dir."
      fi

      return 1
    else
      _is_old_dir_removed=true
    fi
  fi

  if [ ! -d "$_local_opt_dir" ]; then
    log_info "$_funcname" "Creating the '$_local_opt_dir' dir..."

    _status_message=$(mkdir -p "$_local_opt_dir" 2>&1)
    _status_code=$?

    if [ $_status_code -ne 0 ]; then
      if [ -n "$_status_message" ]; then
        log_error "$_funcname" \
          "mkdir (exit: $_status_code): failed to create '$_local_opt_dir' dir:"

        cat <<EOF

${_status_message}

EOF
      else
        log_error "$_funcname" \
          "mkdir (exit: $_status_code): failed to create '$_local_opt_dir' dir."
      fi

      return 1
    fi
  fi

  if [ $_is_old_dir_removed = true ]; then
    log_info "$_funcname" "Extracting new files..."
  fi

  if [ "$g_need_tty" = "yes" ]; then
    _status_message=$(tar -C "$_local_opt_dir" -xzf "$_installation_file" 2>&1 >/dev/tty)
  else
    _status_message=$(tar -C "$_local_opt_dir" -xzf "$_installation_file" 2>&1)
  fi

  _status_code=$?

  if [ "$_status_code" -ne 0 ]; then
    if [ -n "$_status_message" ]; then
      log_error "$_funcname" \
        "tar (exit: $_status_code): extraction failed:"
      cat <<EOF

${_status_message}

EOF
    else
      log_error "$_funcname" \
        "tar (exit: $_status_code): extraction failed."
    fi

    return 1
  fi
}

# process_step6: Configures environment variables (GOROOT, PATH) in the shell profile.
# Detects shell type (bash, zsh, fish, nushell) and updates the appropriate file.
# Arguments: --temp-dir <dir>
# Returns: 0 on success, 1 on error.
process_step6() {
  local _funcname='process_step6'

  local _export_go_bin_path=
  local _export_go_root_path=
  local _profile_file=
  local _go_root_path=
  local _has_gobin_path=false
  local _has_goroot_path=false
  local _temp_dir=

  # Parsing options
  while [ $# -gt 0 ]; do
    case "$1" in
      --temp-dir)
        _temp_dir=$2
        shift
        ;;
      *)
        log_error "$_funcname" \
          "Invalid option ('$1'): usage: $_usage."
        return 1
        ;;
    esac
    shift
  done

  # Detect user's shell and choose the appropriate profile file
  case "$SHELL" in
    */bash)
      if [ -f "$HOME/.bash_profile" ]; then
        _profile_file="$HOME/.bash_profile"
      else
        _profile_file="$HOME/.bashrc"
      fi
      ;;
    */zsh)
      _profile_file="$HOME/.zshrc"
      ;;
    */fish)
      _profile_file="$HOME/.config/fish/config.fish"
      [ -d "$HOME/.config/fish" ] || mkdir -p "$HOME/.config/fish"
      ;;
    */nushell)
      _profile_file="$HOME/.config/nushell/config.toml"
      [ -d "$HOME/.config/nushell" ] || mkdir -p "$HOME/.config/nushell"
      ;;
    *)
      _profile_file="$HOME/.profile" # Fallback
      ;;
  esac

  log_info "$_funcname" \
    "$(set_text bold "STEP 6/$g_total_execution_steps"):"

  log_info "$_funcname" \
    "Configuring environment variables in $_profile_file..."

  # Fetch the Go root directory
  _go_root_path="$(get_go_dir)"

  local _export_go_root_path=
  local _export_go_bin_path=
  local _fish_export_go_root_path=
  local _fish_export_go_bin_path=
  local _nushell_export_go_root_path=
  local _nushell_export_go_bin_path=

  if [ -d "$_go_root_path" ]; then
    _go_root_path=$(printf '%s\n' "$_go_root_path" | sed "s|^$HOME|\\\$HOME|")

    # Prepare the export lines for each shell
    _export_go_root_path="export GOROOT=\"$_go_root_path\""
    _export_go_bin_path="export PATH=\"$_go_root_path/bin:\$PATH\""
    _fish_export_go_root_path="set -gx GOROOT \"$_go_root_path\""
    _fish_export_go_bin_path="set -gx PATH \"$_go_root_path/bin:\$PATH\""
    _nushell_export_go_root_path="let-env GOROOT = \"$_go_root_path\""
    _nushell_export_go_bin_path="let-env PATH = \"$_go_root_path/bin:\$PATH\""
  else
    log_error "$_funcname" \
      "Not a directory: '$_go_root_path'."
    return 1
  fi

  [ -f "$_profile_file" ] || touch "$_profile_file"

  # Normalize lines for grep
  local _normalized_goroot_path=
  local _normalized_gobin_path=

  case "$SHELL" in
    */bash | */zsh)
      _normalized_goroot_path=$(printf "%s" "$_export_go_root_path" | sed 's/[[:space:]]\+/ /g; s/#.*//')
      _normalized_gobin_path=$(printf "%s" "$_export_go_bin_path" | sed 's/[[:space:]]\+/ /g; s/#.*//')
      ;;
    */fish)
      _normalized_goroot_path=$(printf "%s" "$_fish_export_go_root_path" | sed 's/[[:space:]]\+/ /g; s/#.*//')
      _normalized_gobin_path=$(printf "%s" "$_fish_export_go_bin_path" | sed 's/[[:space:]]\+/ /g; s/#.*//')
      ;;
    */nushell)
      _normalized_goroot_path=$(printf "%s" "$_nushell_export_go_root_path" | sed 's/[[:space:]]\+/ /g; s/#.*//')
      _normalized_gobin_path=$(printf "%s" "$_nushell_export_go_bin_path" | sed 's/[[:space:]]\+/ /g; s/#.*//')
      ;;
    *)
      _normalized_goroot_path=$(printf "%s" "$_export_go_root_path" | sed 's/[[:space:]]\+/ /g; s/#.*//')
      _normalized_gobin_path=$(printf "%s" "$_export_go_bin_path" | sed 's/[[:space:]]\+/ /g; s/#.*//')
      ;;
  esac

  # Check if the variables already exist in the profile file
  grep -q "$_normalized_goroot_path" "$_profile_file" && _has_goroot_path=true || _has_goroot_path=false
  grep -q "$_normalized_gobin_path" "$_profile_file" && _has_gobin_path=true || _has_gobin_path=false

  # Logic to handle the profile file modifications
  if [ "$_has_goroot_path" = false ] && [ "$_has_gobin_path" = false ]; then
    # Neither GOROOT nor PATH exists, add both at the end, with check for newline
    # We first check if there's already an empty line at the end, and add only if needed
    tail -n 1 "$_profile_file" | grep -q '^$' || printf '\n' >>"$_profile_file"

    {
      printf "%s\n" "$_normalized_goroot_path"
      printf "%s\n" "$_normalized_gobin_path"
    } >>"$_profile_file"
  elif [ "$_has_goroot_path" = true ] && [ "$_has_gobin_path" = false ]; then
    # Only GOROOT exists, add PATH below it
    awk -v newline="$_normalized_gobin_path" -v target="$_normalized_goroot_path" '
      $0 == target { print; print newline; next }
      { print }
    ' "$_profile_file" >"$_temp_dir/.profile" && mv "$_temp_dir/.profile" "$_profile_file"
  elif [ "$_has_goroot_path" = false ] && [ "$_has_gobin_path" = true ]; then
    # Only PATH exists, add GOROOT above it
    awk -v newline="$_normalized_goroot_path" -v target="$_normalized_gobin_path" '
      $0 == target { print newline; print; next }
      { print }
    ' "$_profile_file" >"$_temp_dir/.profile" && mv "$_temp_dir/.profile" "$_profile_file"
  fi

  # Set the reload command to be displayed at the end of the process
  case "${SHELL##*/}" in
    fish)
      g_reload_command="source ~/.config/fish/config.fish"
      ;;
    nushell)
      g_reload_command="source ~/.config/nushell/config.nu"
      ;;
    *)
      g_reload_command=". $(printf '%s\n' "$_profile_file" | sed "s|^$HOME|\\\$HOME|")"
      ;;
  esac
}

######################################################################
# Getter functions
######################################################################

# get_base_url: Extracts the base domain from a full URL.
# Arguments: --url <URL>
# Output: The base URL (e.g., https://example.com).
# Returns: 0 on success, 1 on error.
get_base_url() {
  local _funcname='get_base_url'
  local _usage="$_funcname --url <URL>"

  local _option="${1-}"
  local _target_url="${2-}"

  if [ $# -ne 2 ]; then
    log_error "$_funcname" \
      "Internal: invalid number of parameters: usage: $_usage."

    return 1
  fi

  case "$_option" in
    --url)
      if [ -z "$_target_url" ]; then
        log_error "$_funcname" \
          "Internal: invalid URL: '$_target_url'."

        return 1
      fi

      printf '%s' "$_target_url" | sed 's|\(https\?://[^/]*\).*|\1|'
      ;;
    *)
      log_error "$_funcname" \
        "Internal: invalid option ('$_option'): usage: $_usage."

      return 1
      ;;
  esac

  return 0
}

# get_checksum: Calculates the hash of a file using sha256sum or sha512sum.
# Arguments: [sha256 | sha512] --file <path>
# Output: The calculated hash string.
# Returns: 0 on success, 1 on error.
get_checksum() {
  local _funcname='get_checksum'
  local _usage="$_funcname [sha256 | sha512] --file <path>. Default: sha256"

  local _1st_param="${1:-}"
  local _2nd_param="${2:-}"
  local _3nd_param="${3:-}"
  local _hash_algorithm='SHA-256'
  local _target_file=

  if [ $# -ge 2 ] && [ $# -lt 3 ]; then
    log_error "$_funcname" \
      "Internal: invalid number of parameters: usage: $_usage."

    return 1
  fi

  case "$_1st_param" in
    --file)
      _target_file="$_2nd_param"
      ;;
    sha256 | sha512)
      [ "$_1st_param" = "sha512" ] && _hash_algorithm='SHA-512'

      if [ "$_2nd_param" != '--file' ]; then
        log_error "$_funcname" \
          "Invalid option ('$_2nd_param'): usage: $_usage."
        return 1
      fi

      if [ ! -f "$_3nd_param" ]; then
        log_error "$_funcname" \
          "Is not a file: '$_3nd_param'."
        return 1
      fi

      _target_file="$_3nd_param"
      ;;
    *)
      log_error "$_funcname" \
        "Invalid first parameter ('$_1st_param'): usage: $_usage."
      return 1
      ;;
  esac

  if [ -z "$_target_file" ] || [ ! -f "$_target_file" ]; then
    log_error "$_funcname" \
      "The payload ('$_target_file') is not a file."
    return 1
  fi

  case "$_hash_algorithm" in
    SHA-256)
      if ! sha256sum "$_target_file" | awk '{ print $1 }'; then
        log_error "$_funcname" "Failed to get SHA256SUM."
        return 1
      fi
      ;;
    SHA-512)
      if ! sha512sum "$_target_file" | awk '{ print $1 }'; then
        log_error "$_funcname" "Failed to get SHA512SUM."
        return 1
      fi
      ;;
    *)
      log_error "$_funcname" \
        "Internal: invalid hash algorithm option: '$_hash_algorithm'."
      return 1
      ;;
  esac

  return 0
}

# get_connection_status: Performs a HEAD request to check URL availability.
# Arguments: --target-url <URL>
# Returns: 0 if available, 1 on connection error or non-2xx/3xx response.
get_connection_status() {
  local _funcname='get_connection_status'
  local _usage="$_funcname --target-url <URL>"

  local _curl_exit_status=
  local _io_tempfile=
  local _option="${1:-}"
  local _response_result=
  local _status_code=
  local _status_message=
  local _target_url="${2:-}"

  if [ $# -ne 2 ]; then
    log_error "$_funcname" \
      "Internal: invalid number of parameters: usage: $_usage."
    return 1
  fi

  case "$_option" in
    --target-url)
      if [ -z "$_target_url" ]; then
        log_error "$_funcname" \
          "Internal: no URL set: usage: $_usage."
        return 1
      fi
      ;;
    *)
      log_error "$_funcname" \
        "Internal: invalid option ('$_option'): usage: $_usage."
      return 1
      ;;
  esac

  _status_message=

  if _status_message=$(get_temporary_file 2>&1); then
    _io_tempfile="$_status_message"
  else
    if [ -n "$_status_message" ]; then
      printf '%b\n' "$_status_message"
    else
      log_error "$_funcname" "Internal: failed to get temporary I/O file."
    fi

    return 1
  fi

  run_curl --silent -LIw '%{http_code}' "$_target_url" >"$_io_tempfile" 2>&1
  _curl_exit_status=$?

  if [ -s "$_io_tempfile" ]; then
    _status_message="$(head -n 1 "$_io_tempfile" | tr -d '\r')"
    _status_code="$(tail -1 "$_io_tempfile")"
    _response_result="$_status_code ('$_status_message')"
  else
    log_error "$_funcname" \
      "Unable to get connection status: unknown reason."
    return 1
  fi

  case $_status_code in
    000)
      local _total_lines_number=
      local _error_message=

      _status_message=

      if _status_message=$(get_total_lines_num --file "$_io_tempfile" 2>&1); then
        _total_lines_number="$_status_message"
      else
        if [ -n "$_status_message" ]; then
          printf '%b\n' "$_status_message"
        else
          log_error "$_funcname" "Internal: failed to get total of lines number."
        fi

        return 1
      fi

      if [ "$_total_lines_number" -gt 1 ]; then
        log_error "$_funcname" "curl (exit: $_curl_exit_status): $_response_result"
      else
        log_error "$_funcname" \
          "curl (exit: $_curl_exit_status): unable to establish connection (status code: ${_status_code})."
        log_warn "$_funcname" "Check your Internet connection."
      fi

      return 1
      ;;
    # HTTP response status codes between 100 to 199.
    1[0-9][0-9])
      log_warn "$_funcname" \
        "Informational response: $_response_result"
      return 1
      ;;
    # HTTP response status codes between 200 to 299.
    2[0-9][0-9])
      # Nothing to do.
      ;;
    # HTTP response status codes between 300 to 399.
    3[0-9][0-9])
      # Nothing to do.
      ;;
    # HTTP response status codes between 400 to 499.
    4[0-9][0-9])
      log_error "$_funcname" \
        "Client error response: $_response_result"
      return 1
      ;;
    # HTTP response status codes between 500 to 599.
    5[0-9][0-9])
      log_error "$_funcname" \
        "Server error response: $_response_result"
      return 1
      ;;
    *)
      local _total_lines_number=
      local _error_message=

      _status_message=

      if _status_message=$(get_total_lines_num --file "$_io_tempfile" 2>&1); then
        _total_lines_number="$_status_message"
      else
        if [ -n "$_status_message" ]; then
          printf '%s\n' "$_status_message"
        else
          log_error "$_funcname" "Internal: failed to get total of lines number."
        fi

        return 1
      fi

      if [ "$_total_lines_number" -gt 1 ]; then
        _error_message="unknown connection response: $_response_result"
      else
        _error_message="unknown connection response (status code: $_status_code)"
      fi

      log_error "$_funcname" "curl (exit: $_curl_exit_status): ${_error_message}."

      return 1
      ;;

  esac

  [ -f "$_io_tempfile" ] && rm "$_io_tempfile"

  return 0
}

# get_diff_between_versions: Calculates the integer difference between two semver-like versions.
# Arguments: --v1 <v1> --v2 <v2>
# Output: The absolute difference as a number.
# Returns: 0 on success, 1 on error.
get_diff_between_versions() {
  local _funcname='get_diff_between_versions'
  local _usage="$_funcname <--v1 <version 1> --v2 <version 2>>"

  local _status_message=
  local _version1=
  local _version1_num=
  local _version2=
  local _version2_num=

  while [ $# -gt 0 ]; do
    case "$1" in
      --v1)
        _version1=$2
        shift
        ;;
      --v2)
        _version2=$2
        shift
        ;;
      *)
        log_error "$_funcname" \
          "Invalid option ('$1'): usage: $_usage."
        return 1
        ;;
    esac
    shift
  done

  _status_message=

  if _status_message=$(get_version_to_num_conversion --version "$_version1" 2>&1); then
    _version1_num="$_status_message"
  else
    if [ -n "$_status_message" ]; then
      log_error "$_funcname" "$_status_message"
    else
      log_error "$_funcname" "Failed to converse '$_version1' to number."
    fi

    return 1
  fi

  _status_message=

  if _status_message=$(get_version_to_num_conversion --version "$_version2" 2>&1); then
    _version2_num="$_status_message"
  else
    if [ -n "$_status_message" ]; then
      printf '%b\n' "$_status_message"
    else
      log_error "$_funcname" "Failed to convert '$_version2' to number."
    fi

    return 1
  fi

  if [ "$_version1_num" -gt "$_version2_num" ]; then
    printf '%s\n' "$((_version1_num - _version2_num))"
  else
    printf '%s\n' "$((_version2_num - _version1_num))"
  fi

  return 0
}

# get_download_server_url: Returns the primary download URL for Go tarballs.
# Output: URL string.
# Returns: Exit status of printf.
get_download_server_url() {
  printf '%s\n' 'https://go.dev/dl'
  return $?
}

# get_execution_step: Manages the list of steps to be performed.
# Arguments: --list | --list-length | --stepN-name
# Output: Space-separated list of steps, the count, or a specific step name.
# Returns: 0 on success, 1 on error.
get_execution_step() {
  local _funcname='get_execution_step'
  local _usage="$_funcname <--list | --list-length | --stepN-name>"

  local _funcparams="$*"
  local _option=
  local _steps_list=
  local _steps_list_len=

  # List of execution steps.
  set -- \
    STEP1 \
    STEP2 \
    STEP3 \
    STEP4 \
    STEP5 \
    STEP6

  _steps_list="$*"
  _steps_list_len="$#"

  # Restore the original positional parameters
  set -- "$_funcparams"

  if [ $# -ne 1 ]; then
    log_error "$_funcname" \
      "Internal: invalid number of parameters: usage: $_usage."
    return 1
  fi

  _option="$1"

  case "$_option" in
    --list)
      printf '%s' "$_steps_list"
      ;;
    --step[0-9]-name)
      local _error_message="Invalid step number"
      local _step_num=

      _step_num="$_option"
      _step_num="${_step_num#--step}" # Remove "--step"
      _step_num="${_step_num%%-name}" # Remove "-name"

      if [ -z "$_step_num" ]; then
        _error_message="${_error_message}: empty value"
        log_error "$_funcname" "${_error_message}."
        return 1
      elif ! echo "$_step_num" | grep -q '^[0-9]*$'; then
        _error_message="$_error_message ($_step_num): is not an integer"
        log_error "$_funcname" "${_error_message}."
        return 1
      elif [ "$_step_num" -le 0 ] 2>/dev/null; then
        _error_message="${_error_message}: negative number"
        log_error "$_funcname" "${_error_message}."
        return 1
      fi

      printf '%s\n' "$_steps_list" | cut -d' ' -f"$_step_num"
      ;;
    --list-length)
      printf '%d' "$_steps_list_len"
      ;;
    *)
      log_error "$_funcname" \
        "Invalid option ('$_option'): usage: '$_usage'."
      return 1
      ;;
  esac

  return 0
}

# get_file_permission: Extracts octal file permissions in a POSIX-compliant way.
# Arguments: <file_path>
# Output: 3-digit octal permission (e.g., 755).
# Returns: 0 on success, 1 on error.
get_file_permission() {
  # POSIX-compliant way to get octal file permissions
  # Usage: get_file_permission <file>

  if [ -z "$1" ] || [ ! -e "$1" ]; then
    return 1
  fi

  # Force consistent ls output
  local permstr=

  # shellcheck disable=SC2012 # Use find instead of ls to better handle non-alphanumeric filenames.
  permstr="$(LC_ALL=C ls -ld -- "$1" 2>/dev/null | awk '{print $1}')"

  if [ -z "$permstr" ]; then
    return 1
  fi

  printf "%s\n" "$permstr" | awk '
    function perm_digit(r, w, x) {
      return (r == "r" ? 4 : 0) + (w == "w" ? 2 : 0) + (x ~ /[xsStT]/ ? 1 : (x == "x" ? 1 : 0))
    }
    {
      user = perm_digit(substr($0,2,1), substr($0,3,1), substr($0,4,1))
      group = perm_digit(substr($0,5,1), substr($0,6,1), substr($0,7,1))
      other = perm_digit(substr($0,8,1), substr($0,9,1), substr($0,10,1))
      printf "%d%d%d\n", user, group, other
    }'
  return 0
}

# get_main_opts: Parses command-line options and updates global settings.
# Arguments: Command-line parameters.
get_main_opts() {
  for arg in "$@"; do
    case "$arg" in
      --assume-yes)
        g_need_tty=no
        ;;
      --help)
        usage
        exit 0
        ;;
      --quiet)
        g_quiet_mode=yes
        ;;
      --remove | --uninstall)
        g_uninstall_mode=yes
        ;;
      --verbose)
        g_verbose_mode=yes
        ;;
      --version)
        get_script_version
        exit 0
        ;;
      *)
        OPTIND=1
        if [ "${arg%%--*}" = "" ]; then
          printf "Error: Unknown option: %s\n" "$arg" >&2
          usage
          return 1
        fi
        while getopts :Vhquvy sub_arg "$arg"; do
          case "$sub_arg" in
            V)
              get_script_version
              exit 0
              ;;
            h)
              usage
              exit 0
              ;;
            q)
              g_quiet_mode=yes
              ;;
            u)
              g_uninstall_mode=yes
              ;;
            v)
              g_verbose_mode=yes
              ;;
            y)
              g_need_tty=no
              ;;
            \? | *)
              printf "Error: Unknown option: -%s\n" "$OPTARG" >&2
              usage
              return 1
              ;;
          esac
        done
        ;;
    esac
  done
}

# get_version_to_num_conversion: Converts a semver string to a comparable integer.
# Arguments: --version <version>
# Output: Integer representation (e.g., 1.2.3 -> 10203).
# Returns: 0 on success, 1 on error.
get_version_to_num_conversion() {
  local _funcname='get_version_to_num_conversion'
  local _usage="$_funcname --version <version – e.g. 1.0.0>"

  local _major=
  local _minor=
  local _option="${1:-}"
  local _patch=
  local _version="${2:-}"

  if [ $# -ne 2 ]; then
    log_error "$_funcname" \
      "Internal: invalid number of parameters: usage: $_usage."
    return 1
  fi

  case "$_option" in
    --version)
      if [ -z "$_version" ]; then
        log_error "$_funcname" \
          "Internal: no version set: usage: $_usage."
        return 1
      fi
      ;;
    *)
      log_error "$_funcname" \
        "Internal: invalid option ('$_option'): usage: $_usage."
      return 1
      ;;
  esac

  _major=$(printf '%s\n' "$_version" | cut -d. -f1)
  _minor=$(printf '%s\n' "$_version" | cut -d. -f2)
  _patch=$(printf '%s\n' "$_version" | cut -d. -f3)

  printf '%s\n' $((_major * 10000 + _minor * 100 + _patch))

  return 0
}

# get_go_basedir: Returns the parent directory where Go will be installed.
# Output: The directory path (e.g., $HOME/.local/opt).
get_go_basedir() {
  dirname "$(get_go_dir)"
  return $?
}

# get_go_bin_path: Returns the full path to the Go binary.
# Output: The binary path (e.g., $HOME/.local/opt/go/bin/go).
get_go_bin_path() {
  printf '%s\n' "$(get_go_dir)/bin/go"
  return $?
}

# get_go_command_path: Retrieves the system path of the 'go' command.
# Output: The path string if found.
# Returns: 0 if found, 1 otherwise.
get_go_command_path() {
  local _funcname='get_go_command_path'

  if is_go_command_found; then
    local _command_exit_status=
    local _status_message=

    _status_message=$(command -v go 2>&1)

    _command_exit_status=$?

    if [ "$_command_exit_status" -eq 0 ]; then
      printf '%s\n' "$_status_message"
    else
      if [ -n "$_status_message" ]; then
        log_error "$_funcname" "command (exit: $_command_exit_status): $_status_message"
      else
        log_error "$_funcname" \
          "command (exit: $_command_exit_status): failed to get Go command path."
      fi
      return 1
    fi
  else
    log_error "$_funcname" \
      "go command not found."
    return 1
  fi

  return 0
}

# get_go_command_version: Retrieves the version of the installed Go compiler.
# Output: The version string (e.g., 1.21.0).
# Returns: 0 if successful, 1 if command not found.
get_go_command_version() {
  local _funcname='get_go_command_version'

  if is_go_command_found; then
    go version | awk '{print $3}' | sed 's/^go//'
  else
    log_error "$_funcname" \
      "go command not found."
    return 1
  fi

  return 0
}

# get_go_dir: Returns the absolute path where Go is installed.
# Output: The directory path.
get_go_dir() {
  printf '%s\n' "$HOME/.local/opt/go"
  return $?
}

# get_machine_architecture: Returns the system hardware name.
# Output: The architecture (e.g., x86_64).
get_machine_architecture() {
  uname --machine
  return $?
}

# get_machine_architecture_tag: Returns the architecture string used in Go filenames.
# Output: '386' or 'amd64'.
# Returns: 0 on success, 1 on invalid architecture.
get_machine_architecture_tag() {
  local _funcname='get_machine_architecture_tag'

  if is_386_architecture; then
    printf '%s\n' '386'
  elif is_amd64_architecture; then
    printf '%s\n' 'amd64'
  else
    log_error "$_funcname" \
      "Invalid architecture: '$(get_machine_architecture)'."
    return 1
  fi

  return 0
}

# get_remote_go_version_str: Fetches the latest Go version string from the server.
# Output: The raw version string (e.g., go1.21.0).
# Returns: 0 on success, 1 on error.
get_remote_go_version_str() {
  local _funcname='get_remote_go_version_str'

  local _curl_exit_status=
  local _current_remote_version=
  local _io_tempfile=
  local _status_message=
  local _version_file_url=

  if _status_message=$(get_version_file_url 2>&1); then
    _version_file_url="$_status_message"
  else
    if [ -n "$_status_message" ]; then
      log_error "$_funcname" "$_status_message"
    else
      log_error "$_funcname" "Internal: failed to get version file URL."
    fi

    return 1
  fi

  _status_message=

  if _status_message=$(get_temporary_file 2>&1); then
    _io_tempfile="$_status_message"
  else
    if [ -n "$_status_message" ]; then
      printf '%b\n' "$_status_message"
    else
      log_error "$_funcname" "Internal: failed to get temporary I/O file."
    fi

    return 1
  fi

  _status_message=

  if ! _status_message=$(get_connection_status --target-url "$_version_file_url" 2>&1); then
    if [ -n "$_status_message" ]; then
      printf '%b\n' "$_status_message"
    else
      log_error "$_funcname" "Failed to get connection status."
    fi

    return 1
  fi

  run_curl --progress-bar --silent "$_version_file_url" >"$_io_tempfile" 2>&1
  _curl_exit_status=$?

  if [ "$_curl_exit_status" -ne 0 ]; then
    return "$_curl_exit_status"
  elif [ -s "$_io_tempfile" ]; then
    if grep --quiet --word-regexp "go.*" "$_io_tempfile"; then
      _current_remote_version=$(head -n1 <"$_io_tempfile" | cut -d " " -f1)
      printf '%s\n' "$_current_remote_version"
    else
      log_error "$_funcname" \
        "Failed to get Go version from '$_version_file_url': version not found."
      return 1
    fi
  else
    log_error "$_funcname" \
      "Failed to get Go version from '$_version_file_url': empty data."
    return 1
  fi

  [ -f "$_io_tempfile" ] && rm "$_io_tempfile"

  return 0
}

# get_script_name: Returns the name of the executable.
# Output: The script name string.
# Returns: 0 on success, 1 on error.
get_script_name() {
  local _script_name='letsgolang'

  if [ -z "$_script_name" ]; then
    _script_name=$(basename "$0" .sh) || return 1
  fi

  printf '%s\n' "$_script_name"

  return 0
}

# get_script_version: Returns the formatted version string including commit and date.
# Output: Full version info string.
get_script_version() {
  printf '%s' "$(get_script_name) $G_SCRIPT_VERSION"

  if [ -n "$G_SCRIPT_COMMIT$G_SCRIPT_DATE" ]; then
    printf ' (%s' "$G_SCRIPT_COMMIT"
    [ -n "$G_SCRIPT_DATE" ] && {
      printf ' %s' "$G_SCRIPT_DATE"
    }
    printf ')'
  fi

  printf '\n'
}

# get_space_char_mask: Returns a safe mask for space characters used in paths.
# Output: Escape sequence for non-breaking space.
get_space_char_mask() {
  printf '%s' '\&nbsp;'
}

# get_temporary_asset: Manages the creation and tracking of temporary files and directories.
# Arguments: <--basename | --directory | --file | --list | --list-length | --template>
# Output: Asset path, basename, or list depending on the option.
# Returns: 0 on success, 1 on error.
get_temporary_asset() {
  local _funcname='get_temporary_asset'
  local _usage="$_funcname <--basename | --directory | --file | --list | --list-lenght | --template>"

  local _asset_basename=
  local _asset_name=
  local _option="${1:-}"
  local _temp_dir="${TMPDIR:-/tmp}"
  local _uid_placeholder='XXXXXX'

  _asset_name="$(get_script_name).$_uid_placeholder"
  _asset_basename="${_asset_name%%"$_uid_placeholder"}"

  if [ $# -ne 1 ] || [ -z "$_option" ]; then
    log_error "$_funcname" \
      "Internal: invalid params: $_usage."
    return 1
  fi

  case "$_option" in
    --basename)
      printf '%s\n' "$_asset_basename"
      ;;
    --directory | --file)
      local _asset_type='directory'
      [ "$_option" = '--file' ] && _asset_type='file'

      local _asset_path=
      local _dir_indicator='.d'
      local _mktemp_exit_status=

      if ! umask 0077; then
        log_error "$_funcname" \
          "Internal: failed to apply 'umask 0077'."
        return 1
      fi

      if [ "$_option" = '--directory' ]; then
        _asset_path=$(mktemp -d "${_temp_dir}/${_asset_name}${_dir_indicator}")
        _mktemp_exit_status=$?
      else
        _asset_path=$(mktemp "${_temp_dir}/${_asset_name}")
        _mktemp_exit_status=$?
      fi

      if [ "$_mktemp_exit_status" -ne 0 ]; then
        log_error "$_funcname" \
          "mktemp (exit: $_mktemp_exit_status): failed to create temporary ${_asset_type}."
        return "$_mktemp_exit_status"
      fi

      if [ -d "$_asset_path" ] || [ -f "$_asset_path" ]; then
        local _desired_permission=700
        [ -f "$_asset_path" ] && _desired_permission=600

        local _current_permission=
        if ! _current_permission=$(get_file_permission "$_asset_path"); then
          log_error "$_funcname" \
            "Failed to get current asset permission value."
          return 1
        fi

        if [ "$_current_permission" -ne "$_desired_permission" ]; then
          local _chmod_exit_status=
          chmod $_desired_permission "$_asset_path"
          _chmod_exit_status=$?

          if [ $_chmod_exit_status -ne 0 ]; then
            log_error "$_funcname" \
              "chmod (exit: $_chmod_exit_status): failed to set asset permission to '$_desired_permission'."
            return "$_chmod_exit_status"
          fi
        fi

        printf '%s\n' "$_asset_path"
      else
        log_error "$_funcname" \
          "Failed to create $_asset_type '$_asset_path': is not a ${_asset_type}."

        return 1
      fi
      ;;
    --list)
      local _find_exit_status=

      find "$_temp_dir" -maxdepth 1 -name "$_asset_basename*" -print0 | sed 's/ /'"$(get_space_char_mask)"'/g' | xargs -0
      _find_exit_status=$?

      if [ $_find_exit_status -ne 0 ]; then
        log_error "$_funcname" \
          "find (exit: $_find_exit_status): failed to find temporary assets."
        return 1
      fi
      ;;
    --list-length)
      local _find_exit_status=

      find "$_temp_dir" -maxdepth 1 -name "letsgo.*" | wc -l
      _find_exit_status=$?

      if [ $_find_exit_status -ne 0 ]; then
        log_error "$_funcname" \
          "find (exit: $_find_exit_status): failed to find temporary assets."
        return 1
      fi
      ;;
    --template)
      local _template="${_temp_dir}/${_asset_name}"
      printf '%s\n' "$_template"
      ;;
    *)
      log_error "$_funcname" \
        "Internal: invalid param: usage: $_usage."
      return 1
      ;;
  esac

  return 0
}

# get_temporary_dir: Creates and returns the path to a temporary directory.
# Output: Path to the new directory.
# Returns: Exit status of the asset creator.
get_temporary_dir() {
  get_temporary_asset --directory
  return $?
}

# get_temporary_file: Creates and returns the path to a temporary file.
# Output: Path to the new file.
# Returns: Exit status of the asset creator.
get_temporary_file() {
  get_temporary_asset --file
  return $?
}

# get_timestamp: Returns a high-resolution timestamp for logging.
# Output: Formatted date string.
# Returns: Exit status of the date command.
get_timestamp() {
  date +"%b %d %H:%M:%S:%N"
  return $?
}

# get_total_lines_num: Counts the number of lines in a file using wc.
# Arguments: --file <path>
# Output: Number of lines.
# Returns: 0 on success, 1 on error.
get_total_lines_num() {
  local _funcname='get_total_lines_num'
  local _usage="$_funcname --file <path>"

  local _option="${1:-}"
  local _target_file="${2:-}"

  if [ $# -ne 2 ]; then
    log_error "$_funcname" \
      "Internal: invalid number of parameters: usage: $_usage."
    return 1
  fi

  case "$_option" in
    --file)
      if [ -z "$_target_file" ] && [ ! -f "$_target_file" ]; then
        local _error_message=

        [ -z "$_target_file" ] \
          && _error_message='no target path detected' \
          || _error_message="the payload ('$_target_file') is not a file"

        log_error "$_funcname" \
          "Internal: $_error_message: usage: $_usage."
        return 1
      fi
      ;;
    *)
      log_error "$_funcname" \
        "Internal: invalid option ('$_option'): usage: $_usage."
      return 1
      ;;
  esac

  if ! wc -l <"$_target_file"; then
    log_error "$_funcname" \
      "Failed to get the number of lines from: ${_target_file}."
    return 1
  fi

  return 0
}

# get_version_file_url: Returns the URL of the text file containing the current Go version.
# Output: URL string.
# Returns: 0 always.
get_version_file_url() {
  printf '%s\n' 'https://go.dev/VERSION?m=text'
  return $?
}

######################################################################
# Setter functions
######################################################################

# set_text: Formats text with ANSI colors or styles using tput.
# Respects the is_no_color check.
# Arguments: [bold | green | red | yellow] <text> [--bold]
# Output: Formatted text string.
# Returns: 0 on success, 1 on invalid arguments.
set_text() {
  local _funcname='set_text'

  if [ $# -ge 2 ] && [ -n "$1" ] && [ -n "$2" ]; then
    local _reset_color=
    local _subcommand="$1"
    local _text=
    local _text_color=
    local _text_color_id=
    local _text_mode=

    _reset_color="$(tput sgr0)"

    case "$_subcommand" in
      bold)
        _text=$2
        _text_color="$(tput bold)"
        ;;
      green | red | yellow)
        local _GREEN_ID=2
        local _RED_ID=1
        local _YELLOW_ID=3

        local _BOLD_MODE=
        local _NORMAL_MODE=

        _BOLD_MODE="$(tput bold)"

        [ "$_subcommand" = 'green' ] && _text_color_id=$_GREEN_ID
        [ "$_subcommand" = 'red' ] && _text_color_id=$_RED_ID
        [ "$_subcommand" = 'yellow' ] && _text_color_id=$_YELLOW_ID

        _text_mode=$_NORMAL_MODE

        while [ $# -gt 0 ]; do
          case "$2" in
            --bold)
              _text=${3:-}
              _text_mode=$_BOLD_MODE
              break
              ;;
            -*)
              _text=${3:-}
              _text_color=$_reset_color
              _text_color_id=0
              break
              ;;
            *)
              _text=$2
              break
              ;;
          esac
          shift
        done

        _text_color=''"${_text_mode}$(tput setaf $_text_color_id)"''
        ;;
      *)
        printf '%s\n' "$2" | grep --quiet "\-.*" && _text=${3:-} || _text=$2
        _text_color=$_reset_color
        ;;
    esac

    if is_no_color; then
      printf '%b\n' "$_text"
    else
      printf '%b\n' "${_text_color}${_text}${_reset_color}"
    fi
  else
    return 1
  fi

  return 0
}

# set_trap: Dispatcher for shell traps (cleanup and abort).
# Arguments: <abort | cleanup [--path <path>]>
# Returns: 0 on success, 1 on error.
set_trap() {
  local _funcname="set_trap"
  local _usage="$_funcname <abort | cleanup [--path <path>]>"

  local _option="${1:-}"

  if [ $# -ge 1 ] || [ $# -le 2 ] && [ -z "$_option" ]; then
    log_error "$_funcname" \
      "Internal: invalid params ('$_option'): usage: $_usage."
    return 1
  fi

  case $_option in
    cleanup)
      local _CLEANUP_OPTION="${2:-}"
      local _asset_path="${3:-}"

      if [ "$_CLEANUP_OPTION" = '--path' ]; then
        if [ -n "$_asset_path" ]; then
          trap_cleanup --path "$_asset_path"
        else
          log_error "$_funcname" \
            "Internal: invalid asset path ('$_asset_path'): usage: ${_usage}."
          return 1
        fi
      else
        trap_cleanup
      fi
      ;;
    abort)
      trap_abort_command
      ;;
    *)
      log_error "$_funcname" \
        "Intrernal: unknown parameter ('$_option'): usage ${_usage}."
      return 1
      ;;
  esac

  return 0
}

######################################################################
# Run Functions
######################################################################

# run_curl: Wrapper for the curl command with security-first defaults.
# Arguments: Arguments passed to curl.
# Returns: Exit status of the curl command.
run_curl() {
  curl --fail --proto '=https' '--tlsv1.2' "$@"
  return $?
}

######################################################################
# Trap Functions
######################################################################

# trap_abort_command: Handles interrupt signals (Ctrl+C).
# Returns: 130 always.
trap_abort_command() {
  local _funcname='trap_abort_command'

  printf '\n'
  log_warn "$_funcname" \
    "The execution was interrupted by <Ctrl-C>."
  return 130
}

# trap_cleanup: Removes temporary assets created during execution.
# Arguments: [--path <path>] (optional)
# Returns: 0 on success, 1 on error.
# shellcheck disable=SC2120 # foo references arguments, but none are ever passed.
trap_cleanup() {
  local _funcname='trap_cleanup'

  local _assets_list=
  local _asset_path="${2:-}"
  local _is_asset_cleanup_by_path=false
  local _option="${1:-}"
  local _status_message=

  if [ $# -ne 2 ] && [ "$_option" != '--path' ] && [ -z "$_asset_path" ]; then
    _assets_list="$(get_temporary_asset --list)" || return 1
  else
    _is_asset_cleanup_by_path=true
    _assets_list="$_asset_path"
  fi

  if [ -n "$_assets_list" ]; then
    local _invalid_assets_list=
    local _rm_exit_status=
    local _rm_failed_list=

    for asset_path in $_assets_list; do
      asset_path="$(printf '%s\n' "$asset_path" | sed 's/'"$(get_space_char_mask)"'/ /g')"

      # Skip if the asset path is not a file or directory to begin with
      if [ ! -f "$asset_path" ] && [ ! -d "$asset_path" ]; then
        _invalid_assets_list="${_invalid_assets_list} ${asset_path}"
        continue
      fi

      # Attempt to forcefully remove the asset
      rm -rf "$asset_path"

      # Verify that the asset was actually removed
      if [ -e "$asset_path" ]; then
        _rm_failed_list="${_rm_failed_list} ${asset_path}"
      fi
    done

    if [ $_is_asset_cleanup_by_path = false ]; then
      if [ -z "$_invalid_assets_list" ] && [ -z "$_rm_failed_list" ]; then
        log_info "$_funcname" \
          "All temporary assets has been removed."
      else
        log_warn "$_funcname" \
          "Failed to remove the following temporary assets:"

        if [ -n "$_invalid_assets_list" ]; then
          printf '%s\n' '    - Invalid assets (not a file or directory):'
          for i in $_invalid_assets_list; do
            printf '%s\n' "        - $i"
          done
        fi

        if [ -n "$_rm_failed_list" ]; then
          printf '%s\n' "    - Failed to remove:"
          for i in $_invalid_assets_list; do
            printf '%s\n' "    - $i"
          done
        fi
      fi
    fi
  fi

  #[ $_is_asset_cleanup_by_path = false ] &&
  #  exit || return 0
  return 0
}

######################################################################
# Log Functions
######################################################################

# log_printf: Base logging function that adds a timestamp in verbose mode.
# Arguments: <message>
# Returns: 0 on success, 1 on invalid arguments.
log_printf() {
  if [ "$g_quiet_mode" = 'yes' ]; then
    return 0
  fi

  if [ $# -ge 1 ] && [ -n "$1" ]; then
    local _timestamp=
    [ "$g_verbose_mode" = 'yes' ] && _timestamp="[$(get_timestamp)] "

    printf "${_timestamp}%b\n" "$1"
  else
    return 1
  fi

  return 0
}

# log_info: Prints an informational message.
# Arguments: [caller_name] <message>
# Returns: 0 on success, 1 on error.
log_info() {
  if [ $# -ge 1 ] && [ -n "$1" ]; then
    local _info_message="$1"
    local _LEVEL_TAG="INFO"

    if [ -n "${2:-}" ]; then
      [ "$g_verbose_mode" = 'yes' ] \
        && _info_message="${_info_message}: $2" || _info_message="$2"
    fi

    log_printf "[$_LEVEL_TAG] $_info_message"
  else
    return 1
  fi

  return 0
}

# log_success: Prints a success message with a colored PASS tag.
# Arguments: [caller_name] <message>
# Returns: 0 on success, 1 on error.
log_success() {
  if [ $# -ge 1 ] && [ -n "$1" ]; then
    local _success_message="$1"
    local _LEVEL_TAG=

    _LEVEL_TAG=$(set_text green --bold "PASS")

    if [ -n "${2:-}" ]; then
      [ "$g_verbose_mode" = 'yes' ] \
        && _success_message="${_success_message}: $2" || _success_message="$2"
    fi

    log_printf "[$_LEVEL_TAG] $_success_message"
  else
    return 1
  fi

  return 0
}

# log_error: Prints an error message with a colored ERROR tag.
# Arguments: [caller_name] <message>
# Returns: 0 on success, 1 on error.
log_error() {
  if [ $# -ge 1 ] && [ -n "$1" ]; then
    local _error_message="$1"
    local _LEVEL_TAG=

    _LEVEL_TAG=$(set_text red --bold "ERROR")

    if [ -n "${2:-}" ]; then
      [ "$g_verbose_mode" = 'yes' ] \
        && _error_message="${_error_message}: $2" || _error_message="$2"
    fi

    log_printf "[$_LEVEL_TAG] $_error_message"
  else
    return 1
  fi

  return 0
}

# log_warn: Prints a warning message with a colored WARN tag.
# Arguments: [caller_name] <message>
# Returns: 0 on success, 1 on error.
log_warn() {
  if [ $# -ge 1 ] && [ -n "$1" ]; then
    local _warn_message=
    local _LEVEL_TAG=

    _LEVEL_TAG=$(set_text yellow --bold "WARN")

    if [ -n "${2:-}" ]; then
      [ "$g_verbose_mode" = 'yes' ] \
        && _warn_message="${_warn_message}: $2" || _warn_message="$2"
    fi

    log_printf "[$_LEVEL_TAG] $_warn_message"
  else
    return 1
  fi

  return 0
}

######################################################################
# Main Execution Guard
# Ensures the script does not run its main routine when sourced for testing.
######################################################################
if [ -z "${SOURCED_FOR_TESTING:-}" ]; then
  main "$@" || exit
fi
