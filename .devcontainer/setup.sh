#!/usr/bin/env bash
set -euxo pipefail

go install github.com/mikefarah/yq/v4@v4.50.1
go install mvdan.cc/sh/v3/cmd/shfmt@v3.12.0

# sudo apt update
# sudo apt install --yes shellcheck
