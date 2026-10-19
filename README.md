# asdf-dvm

An [asdf](https://asdf-vm.com/) plugin for [`dver`](https://github.com/stescobedo92/dotnet-version-manager), the .NET SDK version manager.

> **Important:** this plugin manages **dver versions**, not .NET SDK versions.
> asdf installs the `dver` binary; dver continues to manage .NET SDKs in
> `~/.dver`, exactly as documented by its upstream project.

## Requirements

- asdf `0.14.0` or newer
- `git`, `curl`, and `tar`
- Rust / `cargo` is optional. It is only needed on platforms without a usable
  prebuilt dver binary (see [Platform support](#platform-support)).

## Install

```bash
asdf plugin add dvm https://github.com/<owner>/asdf-dvm.git
asdf install dvm 0.4.0
asdf global dvm 0.4.0
```

Or pin dver per project with `.tool-versions`:

```text
dvm 0.4.0
```

Then:

```bash
asdf install
dver --version
```

## Use dver

This plugin only puts `dver` on your `PATH` through an asdf shim. Use dver to
install and select .NET SDKs:

```bash
dver install 8.0.426
dver use 8.0.426 --global
dver list
```

To make `dotnet` available globally through dver's own shim, run:

```bash
dver setup
```

`dver setup` creates `~/.dver/bin/dotnet` and adds `~/.dver/bin` to your shell
`PATH`. This is separate from asdf's shims.

### Two-layer model

| Layer | Manages | Selected by |
| --- | --- | --- |
| asdf | dver versions | `.tool-versions` / `asdf global` |
| dver | .NET SDK versions | `global.json` / `dver use --global` |

Useful commands:

```bash
asdf list dvm                 # installed dver versions
asdf list all dvm             # installable dver versions
asdf current dvm              # selected dver version
asdf uninstall dvm 0.4.0      # remove dver (does not remove ~/.dver)
```

## Platform support

| Platform | Installation strategy |
| --- | --- |
| Linux x86_64 | Prebuilt release archive |
| macOS arm64 (Apple Silicon) | Prebuilt release archive |
| macOS x86_64 (Intel) | Source build with `cargo` |
| Linux arm64 | Source build with `cargo` |
| Other platforms | Source build if `cargo` is available, otherwise an error |

The upstream `dver-0.4.0-x86_64-apple-darwin.tar.gz` asset currently contains
an **arm64** binary despite its filename. It works on Apple Silicon, but Intel
macOS users need to build from source. This plugin detects unusable prebuilt
binaries and falls back to `cargo install dver` automatically.

Windows is not supported by this plugin directly. Use WSL and the Linux
installation path.

## How it works

- `bin/list-all` lists dver releases from GitHub, excluding versions before
  `0.4.0` and prereleases.
- `bin/download` downloads the matching release archive into
  `$ASDF_DOWNLOAD_PATH`, verifies that the binary can run, and falls back to a
  source build if necessary.
- `bin/install` places the binary at
  `$ASDF_INSTALL_PATH/bin/dver`, where asdf creates its shim.

No `bin/list-bin-paths` script is needed because the binary lives in `bin/`.

## Development

```bash
git clone https://github.com/<owner>/asdf-dvm.git
cd asdf-dvm

asdf plugin add dvm "$PWD"
asdf install dvm 0.4.0
asdf exec dver --version

scripts/lint.bash
```

To test without touching your normal asdf data directory, point asdf at a
temporary directory:

```bash
export ASDF_DATA_DIR="$(mktemp -d)"
asdf plugin add dvm "$PWD"
asdf install dvm 0.4.0
asdf global dvm 0.4.0
asdf exec dver --version
```

## License

MIT
