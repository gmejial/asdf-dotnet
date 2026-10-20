#!/usr/bin/env bash

# Shared helpers for the asdf-dotnet plugin.
#
# This plugin installs .NET SDKs directly with Microsoft's official
# dotnet-install.sh script. The available SDK list is generated from
# Microsoft's release metadata by scripts/update-versions.bash.

set -euo pipefail

TOOL_NAME="dotnet"

PLUGIN_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
VERSIONS_FILE="$PLUGIN_DIR/versions.txt"

fail() {
  echo "asdf-$TOOL_NAME: $*" >&2
  exit 1
}

list_all_versions() {
  [ -f "$VERSIONS_FILE" ] || fail "versions.txt is missing from the plugin."
  cat "$VERSIONS_FILE"
}

list_stable_versions() {
  list_all_versions | grep -v -- '-' || true
}

asdf_command() {
  if [ -n "${ASDF_DIR:-}" ]; then
    if [ -x "$ASDF_DIR/bin/asdf" ]; then
      printf '%s\n' "$ASDF_DIR/bin/asdf"
      return
    fi

    if [ -x "$ASDF_DIR/asdf" ]; then
      printf '%s\n' "$ASDF_DIR/asdf"
      return
    fi
  fi

  printf '%s\n' "asdf"
}

asdf_binary() {
  local asdf_bin

  asdf_bin=$(asdf_command)

  case "$asdf_bin" in
  */*) ;;
  *) asdf_bin=$(command -v "$asdf_bin" || true) ;;
  esac

  if [ -z "$asdf_bin" ] || [ ! -x "$asdf_bin" ]; then
    fail "asdf executable was not found."
  fi

  printf '%s\n' "$asdf_bin"
}

dotnet_install_root() {
  local asdf_bin
  local root

  asdf_bin=$(asdf_binary)
  root=$("$asdf_bin" where dotnet)
  printf '%s\n' "${root%/}"
}

dotnet_sdk_version() {
  local asdf_bin
  local root="$1"
  local version

  version=$(basename "$root")

  if [ ! -d "$root/sdk/$version/Sdks" ]; then
    asdf_bin=$(asdf_binary)
    version=$("$asdf_bin" exec dotnet --version)
  fi

  printf '%s\n' "$version"
}

download_dotnet_installer() {
  local download_path="${ASDF_DOWNLOAD_PATH:?}"
  local installer="$download_path/dotnet-install.sh"

  mkdir -p "$download_path"

  echo "* Downloading dotnet-install.sh..." >&2
  curl -fsSL https://dot.net/v1/dotnet-install.sh -o "$installer"
  chmod +x "$installer"
}

install_version() {
  local install_type="$1"
  local version="${2#v}"
  local install_path="${3%/}"
  local download_path="${ASDF_DOWNLOAD_PATH:?}"
  local installer="$download_path/dotnet-install.sh"
  local cli_home="$download_path/cli-home"

  if [ "$install_type" != "version" ]; then
    fail "asdf-$TOOL_NAME supports release installs only (got ASDF_INSTALL_TYPE=$install_type)."
  fi

  [ -n "$install_path" ] || fail "ASDF_INSTALL_PATH is not set."
  [ -x "$installer" ] || fail "dotnet-install.sh is missing from $download_path."

  rm -rf "${install_path:?}"
  mkdir -p "$install_path"

  echo "* Installing .NET SDK $version into $install_path..." >&2
  if ! "$installer" \
    --install-dir "$install_path" \
    --version "$version" \
    --no-path; then
    rm -rf "${install_path:?}"
    fail "dotnet-install.sh failed to install .NET SDK $version."
  fi

  if [ ! -x "$install_path/dotnet" ]; then
    rm -rf "${install_path:?}"
    fail "dotnet-install.sh completed but $install_path/dotnet is missing."
  fi

  mkdir -p "$cli_home"
  if ! (
    cd "$cli_home" || exit 1
    DOTNET_ROOT="$install_path" \
      DOTNET_MULTILEVEL_LOOKUP=0 \
      DOTNET_CLI_HOME="$cli_home" \
      DOTNET_CLI_TELEMETRY_OPTOUT=1 \
      DOTNET_NOLOGO=1 \
      DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1 \
      "$install_path/dotnet" --version >/dev/null
  ); then
    rm -rf "${install_path:?}" "$cli_home"
    fail "The installed .NET SDK is not executable."
  fi

  rm -rf "$cli_home" "$installer"
  echo ".NET SDK $version installation was successful!"
}

# Sort .NET SDK versions without `sort -V` (Bash 3.2 and BSD sort compatible).
sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1n -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}
