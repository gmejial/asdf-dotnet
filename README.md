# asdf-dotnet

[![Build](https://github.com/gmejial/asdf-dotnet/actions/workflows/build.yml/badge.svg)](https://github.com/gmejial/asdf-dotnet/actions/workflows/build.yml)
[![Lint](https://github.com/gmejial/asdf-dotnet/actions/workflows/lint.yml/badge.svg)](https://github.com/gmejial/asdf-dotnet/actions/workflows/lint.yml)

An [asdf](https://asdf-vm.com/) plugin for the [.NET SDK](https://dotnet.microsoft.com/).

This plugin installs .NET SDKs directly, using Microsoft's official
`dotnet-install.sh` script. It does not wrap another version manager.

> Replacing the archived `hensou/asdf-dotnet` plugin? Remove the old plugin
> first, then add this one:
>
> ```bash
> asdf plugin remove dotnet
> asdf plugin add dotnet https://github.com/gmejial/asdf-dotnet.git
> ```

## Requirements

- asdf `0.14.0` or newer. asdf `0.20.0` and newer use `asdf cmd dotnet ...`
  for plugin commands and `asdf set -u` instead of `asdf global`. The examples
  show the asdf `0.20+` forms with the older forms noted.
- `bash`, `curl`, `tar`, `grep`, and `sed`
- `jq` is optional. It is only needed to maintain `versions.txt` and is used as
  a faster parser when reading `global.json`.
- On Linux, .NET has system dependencies such as ICU. See
  [Microsoft's Linux install documentation](https://learn.microsoft.com/dotnet/core/install/linux).

## Install

```bash
asdf plugin add dotnet https://github.com/gmejial/asdf-dotnet.git
asdf install dotnet 10.0.402

# asdf 0.20+
asdf set -u dotnet 10.0.402

# asdf 0.14-0.19
# asdf global dotnet 10.0.402
```

Or pin an SDK per project with `.tool-versions`:

```text
dotnet 10.0.402
```

Then:

```bash
asdf install
dotnet --version
```

To find and install the newest stable SDK:

```bash
asdf latest dotnet
asdf install dotnet latest
```

## How it works

- `bin/list-all` reads `versions.txt`, a list generated from
  [Microsoft's release metadata](https://builds.dotnet.microsoft.com/dotnet/release-metadata/releases-index.json).
- `bin/download` downloads the official `dotnet-install.sh` installer.
- `bin/install` runs the installer into `$ASDF_INSTALL_PATH` and verifies that
  the installed `dotnet` binary runs.
- `bin/exec-env` sets `DOTNET_ROOT` to the selected SDK, disables multi-level
  lookup, and sets `MSBuildSDKsPath` for the selected SDK.
- `bin/list-bin-paths` exposes the SDK's root `dotnet` binary to asdf.
- `lib/commands/command-exec` and `command-exec.bash` add
  `asdf cmd dotnet exec` on asdf `0.20+` and `asdf dotnet exec` on older
  versions. They run any command with the selected SDK's environment.
- `lib/commands/command-env` and `command-env.bash` add
  `asdf cmd dotnet env` on asdf `0.20+` and `asdf dotnet env` on older
  versions. They print the environment exports for `eval`.

Each SDK version is installed into its own asdf install directory. The SDK
includes the matching .NET runtime, so `dotnet build`, `dotnet run`, and
`dotnet tool` work out of the box.

## global.json

By default, asdf selects the SDK from `.tool-versions`. The .NET CLI also reads
`global.json`, so a project that pins a different SDK can fail even when an SDK
is selected by asdf.

To let asdf read the SDK version from `global.json`, enable asdf's legacy file
support:

```bash
echo 'legacy_version_file = yes' >> ~/.asdfrc
```

The plugin reads `sdk.version` from `global.json`. `.tool-versions` still takes
precedence. For example, with this `global.json`:

```json
{
  "sdk": {
    "version": "8.0.426"
  }
}
```

`asdf current dotnet` reports `8.0.426`, and `asdf install` installs that SDK
when no `.tool-versions` version is set.

`global.json`'s `rollForward` setting is not used to choose a different asdf
install. The plugin pins the exact `sdk.version`; use `asdf install dotnet
<version>` for any other SDK you need.

## Editors, language servers, and global tools

asdf only injects `bin/exec-env` into processes started through its shims.
Running a global tool from `~/.dotnet/tools` directly, or letting an editor
start a language server, does not go through the `dotnet` shim. Those processes
may not see `DOTNET_ROOT` or `MSBuildSDKsPath`.

Prefer local tools when possible:

```bash
dotnet new tool-manifest
dotnet tool install csharp-ls
dotnet tool run csharp-ls
```

Local tools run through the asdf `dotnet` shim, so they get the selected SDK's
environment.

To run a global tool or editor command with the plugin's environment:

```bash
# asdf 0.20+
asdf cmd dotnet exec -- csharp-ls

# asdf 0.14-0.19
asdf dotnet exec csharp-ls
```

`asdf cmd dotnet exec` (or `asdf dotnet exec` on older asdf) sets `DOTNET_ROOT`,
`DOTNET_MULTILEVEL_LOOKUP=0`, and `MSBuildSDKsPath` before running the command.
On asdf `0.20+`, keep the `--` after `exec`; it stops asdf from parsing the
wrapped command's flags. Configure the editor's language server command to use
it, or point the editor at a wrapper:

```bash
#!/usr/bin/env bash
exec asdf cmd dotnet exec -- csharp-ls "$@"
```

On asdf `0.14-0.19`, replace `asdf cmd dotnet exec --` with
`asdf dotnet exec` in the wrapper.

To update the current shell instead:

```bash
# asdf 0.20+
eval "$(asdf cmd dotnet env)"

# asdf 0.14-0.19
eval "$(asdf dotnet env)"
```

An optional prompt hook keeps the variables in sync when the selected SDK
changes. This function works with both asdf command styles. For Bash:

```bash
_asdf_dotnet_env() {
  if asdf cmd dotnet env >/dev/null 2>&1; then
    eval "$(asdf cmd dotnet env 2>/dev/null)" || true
  else
    eval "$(asdf dotnet env 2>/dev/null)" || true
  fi
}
PROMPT_COMMAND="_asdf_dotnet_env${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
```

For Zsh:

```zsh
_asdf_dotnet_env() {
  if asdf cmd dotnet env >/dev/null 2>&1; then
    eval "$(asdf cmd dotnet env 2>/dev/null)" || true
  else
    eval "$(asdf dotnet env 2>/dev/null)" || true
  fi
}
autoload -U add-zsh-hook
add-zsh-hook precmd _asdf_dotnet_env
```

GUI editors launched from the Dock or a desktop launcher may not inherit your
shell environment at all. In that case, launch the editor from a terminal,
configure its environment explicitly, or use the wrapper above.

`csharp-ls` also uses MSBuildLocator, which has known problems with non-standard
SDK locations such as asdf's install directory. If the wrapper still fails, use
the local-tool setup or follow the upstream issue:
[microsoft/MSBuildLocator#210](https://github.com/microsoft/MSBuildLocator/issues/210).

## Version list

`versions.txt` includes stable, preview, and release-candidate SDK versions.
`asdf latest dotnet` excludes previews and release candidates.

The list is refreshed by the `Update versions` GitHub Actions workflow. To
refresh it locally:

```bash
scripts/update-versions.bash
```

This requires `jq`.

## Platform support

| Platform | Supported |
| --- | --- |
| Linux x86_64 | Yes |
| Linux arm64 | Yes |
| macOS arm64 (Apple Silicon) | Yes |
| macOS x86_64 (Intel) | Yes |
| Windows | Use WSL and the Linux installation path |

The installer chooses the correct runtime identifier for the current platform.
Very old SDKs may not publish a build for every platform; in that case the
installer fails with a clear error and the plugin removes the partial install.

## Troubleshooting

**`dotnet: command not found`**

Make sure a version is selected and the shim exists:

```bash
asdf current dotnet

# asdf 0.20+
asdf set -u dotnet 10.0.402

# asdf 0.14-0.19
# asdf global dotnet 10.0.402

asdf reshim dotnet
```

**`invalid command provided: dotnet`**

asdf `0.20+` invokes plugin extension commands through `asdf cmd`:

```bash
asdf cmd dotnet env
asdf cmd dotnet exec -- <command>
```

On asdf `0.14-0.19`, use `asdf dotnet env` and
`asdf dotnet exec <command>` instead.

**`dotnet` cannot find the SDK pinned in `global.json`**

Enable legacy file support as described above, or install the pinned version
explicitly:

```bash
asdf install dotnet <version>
```

**`DOTNET_ROOT` points at another .NET installation**

The plugin sets `DOTNET_ROOT` for commands run through the asdf shim. If your
shell profile sets `DOTNET_ROOT` after asdf initializes, it can override the
selected SDK. Remove the conflicting export or scope it to the commands that
need it.

## Development

```bash
git clone https://github.com/gmejial/asdf-dotnet.git
cd asdf-dotnet

asdf plugin add dotnet "$PWD"
asdf install dotnet 8.0.426

# asdf 0.20+
asdf set -u dotnet 8.0.426

# asdf 0.14-0.19
# asdf global dotnet 8.0.426

asdf exec dotnet --version

# asdf 0.20+
asdf cmd dotnet exec -- dotnet --version
eval "$(asdf cmd dotnet env)"

# asdf 0.14-0.19
# asdf dotnet exec dotnet --version
# eval "$(asdf dotnet env)"

scripts/lint.bash
```

To test without touching your normal asdf data directory:

```bash
export ASDF_DATA_DIR="$(mktemp -d)"
asdf plugin add dotnet "$PWD"
asdf install dotnet 8.0.426

# asdf 0.20+
asdf set -u dotnet 8.0.426

# asdf 0.14-0.19
# asdf global dotnet 8.0.426

asdf exec dotnet --version
```

## License

MIT

Inspired by [hensou/asdf-dotnet](https://github.com/hensou/asdf-dotnet) and
[emersonsoares/asdf-dotnet-core](https://github.com/emersonsoares/asdf-dotnet-core).
