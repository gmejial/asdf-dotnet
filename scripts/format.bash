#!/usr/bin/env bash

set -euo pipefail

shfmt --language-dialect bash --indent 2 --write \
  bin/* \
  lib/* \
  scripts/*
