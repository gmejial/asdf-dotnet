#!/usr/bin/env bash

set -euo pipefail

shellcheck --shell=bash --external-sources \
  bin/* \
  lib/*.bash \
  lib/commands/* \
  scripts/*.bash

shfmt --language-dialect bash --indent 2 --diff \
  bin/* \
  lib/*.bash \
  lib/commands/* \
  scripts/*.bash
