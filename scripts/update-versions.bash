#!/usr/bin/env bash

# Regenerate versions.txt from Microsoft's .NET release metadata.
#
# This script is for maintainers and the update-versions GitHub Actions
# workflow. It is not used at plugin runtime.
#
# Requirements: curl, jq, bash.

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
index_url="https://builds.dotnet.microsoft.com/dotnet/release-metadata/releases-index.json"

# shellcheck source=lib/utils.bash
source "$repo_root/lib/utils.bash"

for command in curl jq; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "update-versions.bash: $command is required." >&2
    exit 1
  }
done

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

echo "* Fetching .NET release metadata..." >&2
curl -fsSL "$index_url" -o "$tmp_dir/releases-index.json"

: >"$tmp_dir/versions"

while IFS= read -r channel_url; do
  [ -n "$channel_url" ] || continue
  echo "* Fetching $channel_url" >&2
  curl -fsSL "$channel_url" -o "$tmp_dir/channel.json"
  jq -r '
    .releases[] |
    if ((.sdks? // []) | length) > 0 then
      .sdks[].version
    else
      (.sdk.version // empty)
    end
  ' "$tmp_dir/channel.json" >>"$tmp_dir/versions"
done < <(jq -r '."releases-index"[] | ."releases.json"' "$tmp_dir/releases-index.json")

awk '!seen[$0]++' "$tmp_dir/versions" >"$tmp_dir/unique-versions"
if sort -V </dev/null >/dev/null 2>&1; then
  sort -V <"$tmp_dir/unique-versions" >"$tmp_dir/versions.txt"
else
  sort_versions <"$tmp_dir/unique-versions" >"$tmp_dir/versions.txt"
fi
mv "$tmp_dir/versions.txt" "$repo_root/versions.txt"

count=$(wc -l <"$repo_root/versions.txt" | tr -d ' ')
echo "* Wrote $count versions to versions.txt" >&2
