#!/usr/bin/env bash
set -euxo pipefail

# renovate: datasource=github-releases depName=nodejs/node packageName=nodejs/node
NODE_VERSION=24.13.0

if type mise &>/dev/null; then
  # pushd /home/codespace/.opencode/plugin/
  # # for plugin opencode-background-agents
  # mise exec node@$NODE_VERSION -- npm i unique-names-generator
  # popd
  mise exec node@$NODE_VERSION -- opencode serve --hostname 0.0.0.0
else
  if type opencode &>/dev/null; then
    # pushd /home/codespace/.opencode/plugin/
    # # for plugin opencode-background-agents
    # npm i unique-names-generator
    # popd
    opencode serve --hostname 0.0.0.0
  else
    echo "ERROR: couldn't run opencode."
    exit 1
  fi
fi
