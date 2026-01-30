#!/usr/bin/env bash
set -euxo pipefail

# renovate: datasource=github-releases depName=nodejs/node packageName=nodejs/node
NODE_VERSION=24.12.0

if type mise &>/dev/null; then
  ## install opencode globally in mise environment
  nohup mise exec node@$NODE_VERSION -- opencode serve &
else
  if type opencode &>/dev/null; then
    nohup opencode serve &
  else
    echo "ERROR: couldn't run opencode."
    exit 1
  fi
fi
