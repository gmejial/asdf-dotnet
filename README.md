# asdf-dotnet

[![Build](https://github.com/gmejial/asdf-dotnet/actions/workflows/build.yml/badge.svg)](https://github.com/gmejial/asdf-dotnet/actions/workflows/build.yml)
[![Lint](https://github.com/gmejial/asdf-dotnet/actions/workflows/lint.yml/badge.svg)](https://github.com/gmejial/asdf-dotnet/actions/workflows/lint.yml)

An [asdf](https://asdf-vm.com/) plugin for the [.NET SDK](https://dotnet.microsoft.com/).

This plugin installs .NET SDKs directly, using Microsoft's official
`dotnet-install.sh` script. It does not wrap another version manager.

## Migrating from hensou/asdf-dotnet

The archived `hensou/asdf-dotnet` plugin used the same `dotnet` plugin name.
`asdf plugin remove dotnet` can delete SDKs installed by the old plugin.

If `~/.asdf/plugins/dotnet` is a Git checkout, switch its remote without
removing the plugin:

```bash
git -C ~/.asdf/plugins/dotnet remote set-url origin https://github.com/gmejial/asdf-dotnet.git
git -C ~/.asdf/plugins/dotnet fetch origin
git -C ~/.asdf/plugins/dotnet reset --hard origin/main
```

If you remove and re-add the plugin instead, reinstall the SDK versions you
still need:

```bash
asdf plugin remove dotnet
asdf plugin add dotnet https://github.com/gmejial/asdf-dotnet.git
asdf install
```

## Requirements

- asdf `0.20.0` or newer. Plugin commands use `asdf cmd dotnet ...`, and the
  examples use `asdf set` instead of the removed `asdf global` command.
- `bash`, `curl`, `tar`, `grep`, and `sed`
- `jq` is optional. It is only needed to maintain `versions.txt` and is used as
  a faster parser when reading `global.json`.
- On Linux, .NET has system dependencies such as ICU. See
  [Microsoft's Linux install documentation](https://learn.microsoft.com/dotnet/core/install/linux).

## Install

```bash
asdf plugin add dotnet https://github.com/gmejial/asdf-dotnet.git
asdf install dotnet 10.0.402
asdf set -u dotnet 10.0.402
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
- `lib/commands/command-exec` adds `asdf cmd dotnet exec`, which runs any
  command with the selected SDK's environment.
- `lib/commands/command-env` adds `asdf cmd dotnet env`, which prints the
  environment exports for `eval`.
- `lib/commands/command-shims` adds `asdf cmd dotnet shims`, which generates
  wrappers for global tools in `~/.dotnet/tools`.

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

## Global tools

Global tools are apphosts in `~/.dotnet/tools`. They do not go through the asdf
`dotnet` shim, so they may not see the selected SDK's environment. Generate
wrappers that run each global tool through `asdf cmd dotnet exec`:

```bash
dotnet tool install --global csharp-ls
asdf cmd dotnet shims
```

Then put the shim directory before `~/.dotnet/tools` on `PATH`:

```bash
export PATH="$HOME/.local/share/asdf-dotnet/bin:$PATH"
```

Add that line to your shell profile. The wrappers resolve the SDK from the
current directory, just like the `dotnet` shim. Rerun `asdf cmd dotnet shims`
after installing, updating, or uninstalling a global tool; it updates wrappers
and removes stale generated ones.

The defaults can be overridden:

```bash
ASDF_DOTNET_GLOBAL_TOOL_PATH=/path/to/tools asdf cmd dotnet shims
ASDF_DOTNET_SHIM_DIR=/path/to/shims asdf cmd dotnet shims
```

A wrapper uses the same two variables when it runs, so a custom tool directory
can also be selected at runtime. Wrapper files carry a generated marker;
`asdf cmd dotnet shims` will not overwrite files it did not create.

## Editors and language servers

For a global language server such as `csharp-ls`, the simplest editor setup is
to point the editor at the generated wrapper:

```bash
#!/usr/bin/env bash
exec "$HOME/.local/share/asdf-dotnet/bin/csharp-ls" "$@"
```

Or use the plugin command directly with the tool's absolute path:

```bash
asdf cmd dotnet exec -- "$HOME/.dotnet/tools/csharp-ls"
```

`asdf cmd dotnet exec` sets `DOTNET_ROOT`, `DOTNET_MULTILEVEL_LOOKUP=0`, and
`MSBuildSDKsPath` before running the command. Keep the `--` after `exec`; it
stops asdf from parsing the wrapped command's flags.

Prefer local tools when possible:

```bash
dotnet new tool-manifest
dotnet tool install csharp-ls
dotnet tool run csharp-ls
```

Local tools run through the asdf `dotnet` shim, so they get the selected SDK's
environment.

To update the current shell instead:

```bash
eval "$(asdf cmd dotnet env)"
```

GUI editors launched from the Dock or a desktop launcher may not inherit your
shell environment. Launch the editor from a terminal, configure its environment
explicitly, or use an absolute wrapper path. The editor should also use the
project directory as its working directory so asdf can resolve the selected
SDK. If you use a custom `ASDF_DATA_DIR`, set it in the editor's environment
too.

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
asdf set -u dotnet 10.0.402
asdf reshim dotnet
```

**A global tool is not found, or the wrapper reports `global tool not found`**

Make sure the tool directory exists and rerun:

```bash
asdf cmd dotnet shims
```

Then check that the shim directory is before `~/.dotnet/tools` on `PATH`:

```bash
command -v csharp-ls
```

**`No version is set for command dotnet` when a global tool starts**

Run the tool from a project with a `.tool-versions` file, or select a user-wide
version with `asdf set -u dotnet <version>`.

**`global.json` is ignored**

Check that `legacy_version_file = yes` is set in `~/.asdfrc` and that no
`.tool-versions` file selects a different version. `.tool-versions` takes
precedence by design.

**An editor still uses the wrong SDK**

The editor may not inherit your shell's environment or may not use the project
directory as its working directory. Use an absolute wrapper path and configure
the project directory in the editor.

## Development

```bash
asdf plugin add dotnet "$PWD"
scripts/test-extension-commands.bash
scripts/lint.bash
```

The extension-command test uses a fake SDK and fake global tool, so it does not
download .NET. The Build workflow installs a real SDK and runs a console
project, a global tool through the generated wrapper, and a `global.json`
resolution check.
