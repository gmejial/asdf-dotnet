#!/usr/bin/env bash

set -euo pipefail

plugin_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

# shellcheck source=lib/utils.bash
source "${plugin_dir}/lib/utils.bash"

root=$(dotnet_install_root)
version=$(dotnet_sdk_version "$root")
sdk_path="$root/sdk/$version/Sdks"

if [ ! -d "$sdk_path" ]; then
  echo "asdf-dotnet: SDK $version was not found under $root/sdk" >&2
  exit 1
fi

printf 'export DOTNET_ROOT=%q\n' "$root"
printf 'export DOTNET_MULTILEVEL_LOOKUP=0\n'
printf 'export MSBuildSDKsPath=%q\n' "$sdk_path"
