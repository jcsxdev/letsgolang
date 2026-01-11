#!/bin/sh
#
# release.sh - Distribution artifact generator for letsgolang
#
# shellcheck disable=SC3043

set -eu

######################################################################
# Pre-flight: ensure script is executed from project root
######################################################################

if [ ! -f "src/letsgolang.sh" ]; then
  echo "Error: src/letsgolang.sh not found. Run this script from the project root." >&2
  exit 1
fi

_OLD_SOURCED="${SOURCED_FOR_TESTING:-}"
export SOURCED_FOR_TESTING=true
# shellcheck disable=SC1091
. "./src/letsgolang.sh"
# Restore the previous state of SOURCED_FOR_TESTING
if [ -z "$_OLD_SOURCED" ]; then
  unset SOURCED_FOR_TESTING
else
  export SOURCED_FOR_TESTING="$_OLD_SOURCED"
fi

# Ensure the library provided the necessary function
if ! command -v get_temporary_dir >/dev/null 2>&1; then
  echo "Error: function 'get_temporary_dir' is missing from src/letsgolang.sh" >&2
  exit 1
fi

######################################################################
# Globals & Cleanup
######################################################################

DIST_DIR="dist"
SRC_SCRIPT="src/letsgolang.sh"
TMP_DIR=""

cleanup() {
  if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
    rm -rf "$TMP_DIR"
  fi
}

trap cleanup EXIT INT TERM

######################################################################
# GPG Wrapper (The Robust Fix)
######################################################################

# Wraps gpg calls to inject --homedir safely if configured
gpg_wrapper() {
  if [ -n "${GPG_HOME:-}" ]; then
    gpg --homedir "$GPG_HOME" "$@"
  else
    gpg "$@"
  fi
}

######################################################################
# Version Detection
######################################################################

detect_version() {
  local _funcname='detect_version'

  if [ -n "${RELEASE_TAG:-}" ]; then
    VERSION="$RELEASE_TAG"
  else
    VERSION="$(git describe --tags 2>/dev/null || true)"
    if [ -z "$VERSION" ]; then
      log_error "$_funcname" "Unable to determine version via git describe --tags."
      exit 1
    fi
  fi

  if [ "${USE_STRIPPED_VERSION:-false}" = "true" ]; then
    VERSION="${VERSION#v}"
    log_info "$_funcname" "Using stripped version: $VERSION"
  else
    log_info "$_funcname" "Using version: $VERSION"
  fi
}

######################################################################
# Directory Preparation
######################################################################

prepare_dist() {
  local _funcname='prepare_dist'
  mkdir -p "$DIST_DIR"
  log_info "$_funcname" "Output directory prepared: $DIST_DIR"
}

######################################################################
# Installer Script Handling
######################################################################

build_installer() {
  local _funcname='build_installer'
  OUT_SCRIPT="${DIST_DIR}/letsgolang.sh"

  cp "$SRC_SCRIPT" "$OUT_SCRIPT"
  chmod +x "$OUT_SCRIPT"

  log_info "$_funcname" "Installer copied to: $OUT_SCRIPT"
}

######################################################################
# Source Tarball Generation
######################################################################

build_tarball() {
  local _funcname='build_tarball'

  # Generate temp dir using the imported library function
  TMP_DIR="$(get_temporary_dir)" || {
    log_error "$_funcname" "Failed to create temporary directory."
    exit 1
  }

  ROOT_DIR="letsgolang-${VERSION}"
  mkdir -p "$TMP_DIR/$ROOT_DIR"

  for f in BUILDING.md CONTRIBUTING.md LICENSE-APACHE LICENSE-MIT README.md SECURITY.md; do
    if [ -f "$f" ]; then
      cp "$f" "$TMP_DIR/$ROOT_DIR/"
    else
      log_warn "$_funcname" "File not found, skipping: $f"
    fi
  done

  cp "$OUT_SCRIPT" "$TMP_DIR/$ROOT_DIR/"

  TARBALL_NAME="letsgolang-${VERSION}.tar.gz"
  TARBALL="${DIST_DIR}/${TARBALL_NAME}"

  # -C is technically not POSIX but widely supported on Linux/BSD/macOS
  tar -czf "$TARBALL" -C "$TMP_DIR" "$ROOT_DIR"

  log_info "$_funcname" "Source tarball created: $TARBALL"
}

######################################################################
# Unified CHECKSUMS.txt
######################################################################

generate_checksums() {
  local _funcname='generate_checksums'
  local _cwd

  CHECKSUMS_FILE="${DIST_DIR}/CHECKSUMS.txt"

  _cwd="$(pwd)"
  cd "$DIST_DIR" || exit 1

  {
    sha256sum "letsgolang.sh"
    sha512sum "letsgolang.sh"
    sha256sum "$(basename "$TARBALL")"
    sha512sum "$(basename "$TARBALL")"
  } >"CHECKSUMS.txt"

  cd "$_cwd" || exit 1

  log_info "$_funcname" "Unified CHECKSUMS.txt generated (relative paths)."
}

######################################################################
# GPG Key Validation (Option A — strict)
######################################################################

validate_sign_key() {
  local _funcname='validate_sign_key'
  local _key="$1"

  # Full fingerprint (40 hex)
  if printf "%s" "$_key" | grep -Eq '^[A-Fa-f0-9]{40}$'; then
    return 0
  fi

  # Long key ID (16 hex)
  if printf "%s" "$_key" | grep -Eq '^[A-Fa-f0-9]{16}$'; then
    return 0
  fi

  log_error "$_funcname" "Invalid signing key. Must be:
    - 16‑digit long key ID
    - 40‑digit fingerprint"
  exit 1
}

######################################################################
# GPG Signing
######################################################################

resolve_sign_key() {
  local _funcname='resolve_sign_key'

  if [ -n "${SIGN_KEY:-}" ]; then
    validate_sign_key "$SIGN_KEY"
  else
    SIGN_KEY="$(git config --local user.signingkey || true)"
    [ -z "$SIGN_KEY" ] && SIGN_KEY="$(git config --global user.signingkey || true)"
    [ -z "$SIGN_KEY" ] && {
      log_error "$_funcname" "No signing key found. Use --sign-key <ID>."
      exit 1
    }
    validate_sign_key "$SIGN_KEY"
  fi

  # Pre-check key existence in the specific keyring (via wrapper)
  if ! gpg_wrapper --list-keys "$SIGN_KEY" >/dev/null 2>&1; then
    log_error "$_funcname" "Signing key not found in keyring: $SIGN_KEY"
    if [ -n "${GPG_HOME:-}" ]; then
      log_error "$_funcname" "(Checked in custom homedir: $GPG_HOME)"
    fi
    exit 1
  fi
}

sign_artifact() {
  local _funcname='sign_artifact'
  local _file="$1"

  if [ "${ENABLE_SIGNING:-false}" != "true" ]; then
    return 0
  fi

  if [ ! -f "$_file" ]; then
    log_warn "$_funcname" "Artifact not found, cannot sign: $_file"
    return
  fi

  log_info "$_funcname" "Signing: $_file"

  # Use gpg_wrapper instead of gpg
  if [ "${SIGN_BATCH:-false}" = "true" ]; then
    gpg_wrapper --batch --yes --armor --local-user "$SIGN_KEY" --detach-sign "$_file"
  else
    gpg_wrapper --armor --local-user "$SIGN_KEY" --detach-sign "$_file"
  fi
}

sign_all() {
  local _funcname='sign_all'

  if [ "${ENABLE_SIGNING:-false}" != "true" ]; then
    log_info "$_funcname" "Signing disabled."
    return 0
  fi

  resolve_sign_key

  sign_artifact "$OUT_SCRIPT"
  sign_artifact "$TARBALL"
  sign_artifact "$CHECKSUMS_FILE"

  log_success "$_funcname" "All artifacts signed."
}

######################################################################
# Argument Parsing
######################################################################

parse_args() {
  local _funcname='parse_args'

  RELEASE_TAG=""
  USE_STRIPPED_VERSION=false
  ENABLE_SIGNING=false
  SIGN_BATCH=false
  SIGN_KEY=""
  # Default to Env Var or Empty
  GPG_HOME="${GNUPGHOME:-}"

  while [ $# -gt 0 ]; do
    case "$1" in
      --release)
        RELEASE_TAG="$2"
        shift 2
        ;;
      --stripped)
        USE_STRIPPED_VERSION=true
        shift 1
        ;;
      --sign)
        ENABLE_SIGNING=true
        shift 1
        ;;
      --sign-key)
        SIGN_KEY="$2"
        shift 2
        ;;
      --gpg-home)
        GPG_HOME="$2"
        shift 2
        ;;
      --sign-batch)
        SIGN_BATCH=true
        shift 1
        ;;
      *)
        echo "Error: Unknown argument: $1" >&2
        exit 1
        ;;
    esac
  done
}

######################################################################
# Main Routine
######################################################################

main() {
  local _funcname='main'

  parse_args "$@"

  detect_version
  prepare_dist
  build_installer
  build_tarball
  generate_checksums
  sign_all

  log_success "$_funcname" "Release artifacts generated successfully."
  log_success "$_funcname" "Stored in: $DIST_DIR/"
}

if [ -z "${SOURCED_FOR_TESTING:-}" ]; then
  main "$@"
fi
