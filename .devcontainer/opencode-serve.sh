#!/usr/bin/env bash
set -euxo pipefail

# renovate: datasource=github-releases depName=nodejs/node packageName=nodejs/node
NODE_VERSION=24.12.0

if type mise &>/dev/null; then
  ## install opencode globally in mise environment
  mise exec node@$NODE_VERSION -- opencode serve --hostname 0.0.0.0
else
  if type opencode &>/dev/null; then
    opencode serve --hostname 0.0.0.0
  else
    echo "ERROR: couldn't run opencode."
    exit 1
  fi
fi
