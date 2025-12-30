#!/bin/sh
#
# run_tests.sh - Robust unit test runner for the letsgolang project.
#
# This script automatically discovers and executes test functions (test_*)
# from scripts in the test/ directory. It provides isolated execution for
# each test, supports filtering, and tracks execution time.
#
# shellcheck disable=SC3043 # In POSIX sh, local is undefined but widely supported.

set -u

# Export this so sourced scripts know we are testing context.
export SOURCED_FOR_TESTING=true

######################################################################
# Global variables
######################################################################

# Counters and state tracking for the test session.
G_TOTAL_TESTS=0    # Incrementing count of all executed tests
G_TOTAL_FAILURES=0 # Count of tests that returned non-zero status
G_START_TIME=0     # Unix timestamp at start of execution
G_FILTER=""        # Filter pattern for test function names
G_FILE_FILTER=""   # Path to a specific test file to run
G_HAS_MS=false     # Whether the system supports millisecond precision

######################################################################
# Utility Functions
######################################################################

# set_text: Wrapper to use the styling function from the project script.
# This isolation prevents 'readonly' variable pollution in the runner.
# Arguments: [style] <text>
# Output: Formatted text string.
set_text() {
  (
    # shellcheck disable=SC1091 # Not following.
    . ./src/letsgolang.sh >/dev/null 2>&1
    set_text "$@"
  )
}

# display_help: Prints the usage instructions.
display_help() {
  cat <<EOF
Robust Shell Test Runner

Usage: ./scripts/run_tests.sh [OPTIONS]

Options:
  -h, --help          Display this help message.
  -f, --file <path>   Run tests only in the specified file.
  -k, --filter <str>  Run only tests matching the specified string.
  --no-color          Disable colored output.

EOF
}

# get_now: Returns the current timestamp in milliseconds if supported, or seconds.
get_now() {
  if [ "$G_HAS_MS" = "true" ]; then
    date +%s%3N
  else
    date +%s
  fi
}

# check_ms_support: Detects if the system's date command supports %3N.
check_ms_support() {
  case $(date +%s%3N 2>/dev/null) in
    [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]*) G_HAS_MS=true ;;
    *) G_HAS_MS=false ;;
  esac
}

# format_duration: Formats a duration (in s or ms) for display.
# Arguments: <duration>
format_duration() {
  local _d="$1"
  if [ "$G_HAS_MS" = "true" ]; then
    if [ "$_d" -lt 1000 ]; then
      printf "%dms" "$_d"
    else
      local _s=$((_d / 1000))
      local _m=$((_d % 1000))
      printf "%d.%03ds" "$_s" "$_m"
    fi
  else
    printf "%ds" "$_d"
  fi
}

######################################################################
# Core Test Logic
######################################################################

# run_test_file: Parses and executes all test functions within a file.
# Arguments: <test_file_path>
run_test_file() {
  local _test_file="$1"
  local _functions
  local _func

  # Extract test functions defined as 'test_something() {'
  _functions=$(grep -E '^test_[a-zA-Z0-9_]+\s*\(\)' "$_test_file" | cut -d'(' -f1)

  if [ -z "$_functions" ]; then
    return
  fi

  # Filter functions if a keyword filter was provided via -k/--filter
  if [ -n "$G_FILTER" ]; then
    local _filtered_functions=""
    for _func in $_functions; do
      if printf "%s" "$_func" | grep -q "$G_FILTER"; then
        _filtered_functions="$_filtered_functions $_func"
      fi
    done
    _functions=$_filtered_functions
  fi

  [ -z "$_functions" ] && return

  printf "\n%s\n" "$(set_text bold "FILE: $_test_file")"

  for _func in $_functions; do
    G_TOTAL_TESTS=$((G_TOTAL_TESTS + 1))

    local _output_file
    _output_file=$(mktemp)
    local _t_start
    _t_start=$(get_now)

    # Indicate the current test being executed.
    printf " %s %s..." "$(set_text bold "RUN")" "$_func"

    # Execution in a fresh shell process ensures environment isolation.
    # It also handles optional setUp and tearDown hooks if defined in the test file.
    if sh -c "
            export SOURCED_FOR_TESTING=true
            . '$_test_file'
            if command -v setUp >/dev/null; then setUp; fi
            $_func
            _inner_exit_code=\$?
            if command -v tearDown >/dev/null; then tearDown; fi
            exit \$_inner_exit_code
        " >"$_output_file" 2>&1; then
      local _t_end
      _t_end=$(get_now)
      local _duration=$((_t_end - _t_start))
      local _unit="ms"
      if [ "$G_HAS_MS" = "false" ]; then _unit="s"; fi
      # Update the line with success status and duration.
      printf "\r\033[K %s %s (%s%s)\n" "$(set_text green "✓")" "$(set_text green "$_func")" "$_duration" "$_unit"
      rm "$_output_file"
    else
      G_TOTAL_FAILURES=$((G_TOTAL_FAILURES + 1))
      # Update the line with failure status.
      printf "\r\033[K %s %s\n" "$(set_text red "✕")" "$(set_text red "$_func")"
      printf "%s\n" "$(set_text red "  --- FAILURE OUTPUT ---")"
      sed 's/^/    /' "$_output_file"
      printf "\n"
      rm "$_output_file"
    fi
  done
}

######################################################################
# Main Entry Point
######################################################################

# main: Orchestrates the test session.
main() {
  check_ms_support
  G_START_TIME=$(get_now)

  # Argument parsing
  while [ $# -gt 0 ]; do
    case "$1" in
      -h | --help)
        display_help
        return 0
        ;;
      -f | --file)
        G_FILE_FILTER="$2"
        shift
        ;;
      -k | --filter)
        G_FILTER="$2"
        shift
        ;;
      --no-color)
        export NO_COLOR=true
        ;;
      *)
        printf "Error: Unknown option: %s\n" "$1" >&2
        return 1
        ;;
    esac
    shift
  done

  # Process requested files
  if [ -n "$G_FILE_FILTER" ]; then
    if [ ! -f "$G_FILE_FILTER" ]; then
      printf "Error: Test file not found: %s\n" "$G_FILE_FILTER" >&2
      return 1
    fi
    run_test_file "$G_FILE_FILTER"
  else
    local _file
    for _file in test/test_*.sh; do
      [ -e "$_file" ] || continue
      run_test_file "$_file"
    done
  fi

  # Summarize results
  local _end_time
  _end_time=$(get_now)
  local _duration=$((_end_time - G_START_TIME))
  local _formatted_time
  _formatted_time=$(format_duration "$_duration")

  printf "\n------------------------------------------------\n"
  if [ "$G_TOTAL_FAILURES" -eq 0 ]; then
    printf "%s\n" "$(set_text green "PASSED: $G_TOTAL_TESTS tests in $_formatted_time")"
    return 0
  else
    printf "%s\n" "$(set_text red "FAILED: $G_TOTAL_FAILURES out of $G_TOTAL_TESTS tests failed in $_formatted_time")"
    return 1
  fi
}

main "$@" || exit
