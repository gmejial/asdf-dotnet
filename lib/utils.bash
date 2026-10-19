#!/usr/bin/env bash

# Shared helpers for the asdf-dvm plugin.
#
# This plugin installs the `dver` binary. It does not manage .NET SDK
# versions; dver itself does that in ~/.dver.

set -euo pipefail

GH_REPO="https://github.com/stescobedo92/dotnet-version-manager"
TOOL_NAME="dvm"

fail() {
  echo -e "asdf-$TOOL_NAME: $*" >&2
  exit 1
}

curl_opts=(-fsSL)

# Version sorting that works on Bash 3.2 and avoids `sort -V`.
sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
  git ls-remote --tags --refs "$GH_REPO" |
    grep -o 'refs/tags/.*' | cut -d/ -f3- |
    sed 's/^v//'
}

# Tags before 0.4.0 used unrelated raw-binary assets and are intentionally
# excluded. 0.4.0 is the first release with the current archive layout.
list_all_versions() {
  list_github_tags |
    grep -v -- '-' |
    awk -F. '
      $1 !~ /^[0-9]+$/ || $2 !~ /^[0-9]+$/ { next }
      {
        major = $1 + 0
        minor = $2 + 0
        patch = ($3 == "" ? 0 : $3 + 0)
        if (major > 0 || (major == 0 && minor >= 4)) {
          print major "." minor "." patch
        }
      }' |
    sort_versions
}

platform_label() {
  local os arch

  case "$(uname -s)" in
  Darwin) os="macOS" ;;
  Linux) os="Linux" ;;
  *) os="$(uname -s)" ;;
  esac

  case "$(uname -m)" in
  arm64 | aarch64) arch="arm64" ;;
  x86_64 | amd64) arch="x86_64" ;;
  *) arch="$(uname -m)" ;;
  esac

  echo "$os $arch"
}

# Return the dver release suffix used by the v0.4.0+ archives, or an empty
# string when no prebuilt asset is expected to work.
#
# Note: the upstream macOS asset is named "x86_64-apple-darwin" but currently
# contains an arm64 binary. We still try it and fall back to a source build if
# it cannot run on this machine.
prebuilt_target() {
  case "$(uname -s):$(uname -m)" in
  Linux:x86_64 | Linux:amd64) echo "x86_64-unknown-linux-gnu" ;;
  Darwin:arm64 | Darwin:aarch64 | Darwin:x86_64) echo "x86_64-apple-darwin" ;;
  *) echo "" ;;
  esac
}

binary_runs() {
  local binary="$1"
  [ -x "$binary" ] || return 1
  "$binary" --version >/dev/null 2>&1
}

build_from_source() {
  local version="$1"
  local download_path="${ASDF_DOWNLOAD_PATH:?}"

  command -v cargo >/dev/null 2>&1 || fail \
    "No usable prebuilt dver binary for $(platform_label), and cargo is not installed. Install Rust from https://rustup.rs and retry."

  echo "* No usable prebuilt dver binary for $(platform_label)." >&2
  echo "* Building dver $version from source with cargo..." >&2

  rm -rf "${download_path:?}/bin" "$download_path/dver"

  if ! cargo install --locked --version "$version" --root "$download_path" dver; then
    rm -rf "${download_path:?}/bin" "$download_path/dver" "$download_path/.crates.toml" "$download_path/.crates2.json"
    fail "cargo install dver $version failed."
  fi

  [ -x "$download_path/bin/dver" ] ||
    fail "cargo reported success but $download_path/bin/dver is missing."

  binary_runs "$download_path/bin/dver" ||
    fail "The dver binary built from source is not executable on $(platform_label)."
}

download_release() {
  local version="${1#v}"
  local download_path="${ASDF_DOWNLOAD_PATH:?}"
  local target archive url

  mkdir -p "$download_path"
  rm -f "$download_path/dver" "$download_path"/.dver-*.tar.gz
  rm -rf "${download_path:?}/bin"

  target="$(prebuilt_target)"

  if [ -n "$target" ]; then
    archive="$download_path/.dver-$version.tar.gz"
    url="$GH_REPO/releases/download/v$version/dver-$version-$target.tar.gz"

    echo "* Downloading dver $version for $(platform_label)..." >&2
    if curl "${curl_opts[@]}" -o "$archive" "$url"; then
      if tar -xzf "$archive" -C "$download_path" dver; then
        chmod +x "$download_path/dver"
        if binary_runs "$download_path/dver"; then
          rm -f "$archive"
          return 0
        fi
      fi
    fi

    rm -f "$archive" "$download_path/dver"
    echo "* The prebuilt dver binary is not usable on $(platform_label)." >&2
  else
    echo "* No prebuilt dver binary is available for $(platform_label)." >&2
  fi

  build_from_source "$version"
}

install_version() {
  local install_type="$1"
  local version="${2#v}"
  local install_path="${3%/}"
  local download_path="${ASDF_DOWNLOAD_PATH:?}"
  local bin_dir source_bin

  if [ "$install_type" != "version" ]; then
    fail "asdf-$TOOL_NAME supports release installs only (got ASDF_INSTALL_TYPE=$install_type)."
  fi

  [ -n "$install_path" ] || fail "ASDF_INSTALL_PATH is not set."

  if [ -f "$download_path/dver" ]; then
    source_bin="$download_path/dver"
  elif [ -f "$download_path/bin/dver" ]; then
    source_bin="$download_path/bin/dver"
  else
    fail "Could not find the downloaded dver binary in $download_path."
  fi

  bin_dir="$install_path/bin"
  mkdir -p "$bin_dir"
  cp "$source_bin" "$bin_dir/dver"
  chmod +x "$bin_dir/dver"

  if ! binary_runs "$bin_dir/dver"; then
    rm -rf "${install_path:?}"
    fail "The installed dver binary is not executable on $(platform_label)."
  fi

  echo "dver $version installation was successful!"
}
