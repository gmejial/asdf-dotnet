#!/usr/bin/env bash

set -euo pipefail

plugin_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

export ASDF_DATA_DIR="$tmp/data"
export PATH="$tmp/bin:$PATH"

export ASDF_DOTNET_SDK_GLOBAL_TOOL_PATH="$tmp/global-tools"
export ASDF_DOTNET_SDK_SHIM_DIR="$tmp/shims"

asdf plugin add dotnet-sdk "$plugin_dir" >/dev/null

install_path="$ASDF_DATA_DIR/installs/dotnet-sdk/8.0.426"
mkdir -p "$install_path/sdk/8.0.426/Sdks" "$tmp/project" "$tmp/bin" "$tmp/global-tools" "$tmp/shims"

cat >"$tmp/bin/dotnet" <<'EOF'
#!/usr/bin/env bash
printf 'args=%s\n' "$*"
printf 'root=%s\n' "$DOTNET_ROOT"
printf 'lookup=%s\n' "$DOTNET_MULTILEVEL_LOOKUP"
printf 'sdks=%s\n' "$MSBuildSDKsPath"
EOF
chmod +x "$tmp/bin/dotnet"

cat >"$tmp/global-tools/csharp-ls" <<'EOF'
#!/usr/bin/env bash
printf 'global-args=%s\n' "$*"
printf 'global-root=%s\n' "$DOTNET_ROOT"
printf 'global-lookup=%s\n' "$DOTNET_MULTILEVEL_LOOKUP"
printf 'global-sdks=%s\n' "$MSBuildSDKsPath"
EOF
chmod +x "$tmp/global-tools/csharp-ls"

printf '#!/usr/bin/env bash\n' >"$tmp/global-tools/custom-tool"
chmod +x "$tmp/global-tools/custom-tool"

printf 'dotnet-sdk 8.0.426\n' >"$tmp/project/.tool-versions"
cd "$tmp/project"

asdf cmd dotnet-sdk env >"$tmp/env.out"
grep -F "export DOTNET_ROOT=$install_path" "$tmp/env.out" >/dev/null
grep -F "export DOTNET_MULTILEVEL_LOOKUP=0" "$tmp/env.out" >/dev/null
grep -F "export MSBuildSDKsPath=$install_path/sdk/8.0.426/Sdks" "$tmp/env.out" >/dev/null

asdf cmd dotnet-sdk exec -- dotnet --version >"$tmp/exec.out"
grep -F "args=--version" "$tmp/exec.out" >/dev/null
grep -F "root=$install_path" "$tmp/exec.out" >/dev/null
grep -F "lookup=0" "$tmp/exec.out" >/dev/null
grep -F "sdks=$install_path/sdk/8.0.426/Sdks" "$tmp/exec.out" >/dev/null

printf 'custom file\n' >"$tmp/shims/custom-tool"
asdf cmd dotnet-sdk shims >"$tmp/shims.out"
grep -F "Global tool directory: $tmp/global-tools" "$tmp/shims.out" >/dev/null
grep -F "Shim directory: $tmp/shims" "$tmp/shims.out" >/dev/null
grep -F "export PATH=$tmp/shims:\$PATH" "$tmp/shims.out" >/dev/null
grep -F "Created 1, removed 0, skipped 1." "$tmp/shims.out" >/dev/null
[ -x "$tmp/shims/csharp-ls" ]
grep -F "custom file" "$tmp/shims/custom-tool" >/dev/null

asdf cmd dotnet-sdk shims >"$tmp/shims2.out"
grep -F "Created 0, removed 0, skipped 1." "$tmp/shims2.out" >/dev/null

"$tmp/shims/csharp-ls" --version >"$tmp/global.out"
grep -F "global-args=--version" "$tmp/global.out" >/dev/null
grep -F "global-root=$install_path" "$tmp/global.out" >/dev/null
grep -F "global-lookup=0" "$tmp/global.out" >/dev/null
grep -F "global-sdks=$install_path/sdk/8.0.426/Sdks" "$tmp/global.out" >/dev/null

rm "$tmp/global-tools/csharp-ls"
asdf cmd dotnet-sdk shims >"$tmp/shims3.out"
grep -F "Created 0, removed 1, skipped 1." "$tmp/shims3.out" >/dev/null
[ ! -e "$tmp/shims/csharp-ls" ]
grep -F "custom file" "$tmp/shims/custom-tool" >/dev/null

ASDF_INSTALL_PATH="$install_path" ASDF_INSTALL_VERSION=8.0.426 \
  bash -c 'source "$1/bin/exec-env"; printf "%s\n" "$MSBuildSDKsPath"' _ "$plugin_dir" >"$tmp/exec-env.out"
grep -F "$install_path/sdk/8.0.426/Sdks" "$tmp/exec-env.out" >/dev/null

printf 'Extension command tests passed.\n'
