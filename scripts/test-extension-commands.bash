#!/usr/bin/env bash

set -euo pipefail

plugin_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

export ASDF_DATA_DIR="$tmp/data"
export PATH="$tmp/bin:$PATH"

asdf plugin add dotnet "$plugin_dir" >/dev/null

install_path="$ASDF_DATA_DIR/installs/dotnet/8.0.426"
mkdir -p "$install_path/sdk/8.0.426/Sdks" "$tmp/project" "$tmp/bin"

cat >"$tmp/bin/dotnet" <<'EOF'
#!/usr/bin/env bash
printf 'args=%s\n' "$*"
printf 'root=%s\n' "$DOTNET_ROOT"
printf 'lookup=%s\n' "$DOTNET_MULTILEVEL_LOOKUP"
printf 'sdks=%s\n' "$MSBuildSDKsPath"
EOF
chmod +x "$tmp/bin/dotnet"

printf 'dotnet 8.0.426\n' >"$tmp/project/.tool-versions"
cd "$tmp/project"

asdf_ext=(asdf dotnet)
if asdf cmd --help >/dev/null 2>&1; then
  asdf_ext=(asdf cmd dotnet)
fi

"${asdf_ext[@]}" env >"$tmp/env.out"
grep -F "export DOTNET_ROOT=$install_path" "$tmp/env.out" >/dev/null
grep -F "export DOTNET_MULTILEVEL_LOOKUP=0" "$tmp/env.out" >/dev/null
grep -F "export MSBuildSDKsPath=$install_path/sdk/8.0.426/Sdks" "$tmp/env.out" >/dev/null

"${asdf_ext[@]}" exec -- dotnet --version >"$tmp/exec.out"
grep -F "args=--version" "$tmp/exec.out" >/dev/null
grep -F "root=$install_path" "$tmp/exec.out" >/dev/null
grep -F "lookup=0" "$tmp/exec.out" >/dev/null
grep -F "sdks=$install_path/sdk/8.0.426/Sdks" "$tmp/exec.out" >/dev/null

ASDF_INSTALL_PATH="$install_path" ASDF_INSTALL_VERSION=8.0.426 \
  bash -c 'source "$1/bin/exec-env"; printf "%s\n" "$MSBuildSDKsPath"' _ "$plugin_dir" >"$tmp/exec-env.out"
grep -F "$install_path/sdk/8.0.426/Sdks" "$tmp/exec-env.out" >/dev/null

printf 'Extension command tests passed.\n'
