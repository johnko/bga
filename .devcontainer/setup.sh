#!/usr/bin/env bash
set -euxo pipefail

# renovate: datasource=github-releases depName=nodejs/node packageName=nodejs/node
NODE_VERSION=24.13.0

# renovate: datasource=github-releases depName=anomalyco/opencode packageName=anomalyco/opencode
OPENCODE_VERSION=v1.1.48

if type mise &>/dev/null; then
  ## install opencode globally in mise environment
  mise exec node@$NODE_VERSION -- npm install --global opencode-ai@$OPENCODE_VERSION
else
  if type npm &>/dev/null; then
    npm install --global opencode-ai@$OPENCODE_VERSION
  else
    echo "ERROR: couldn't install opencode."
    exit 1
  fi
fi
