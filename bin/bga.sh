#!/usr/bin/env bash
set -euo pipefail

# renovate: datasource=github-releases depName=nodejs/node packageName=nodejs/node
NODE_VERSION=24.12.0

# renovate: datasource=github-releases depName=devcontainers/cli packageName=devcontainers/cli
DEVCONTAINERS_VERSION=v0.81.0

DEPENDENCIES="
docker
jq
mise
"

help() {
  cat <<EOF
Usage:
  $0 [command] [parameters...]

Commands:
  help                            Shows this help message.
  setup                           Checks and installs required
                                  dependencies.
  new ./local/path branch-name    Creates git worktree from local
                                  repo, then create or checkout
                                  branch, starts Devcontainer,
                                  starts OpenCode.
EOF
  exit 1
}

_check_command_exists() {
  if type "$1" &>/dev/null; then
    echo "- $1 ✅" >&2
    echo 0
  else
    echo "- $1 ❌" >&2
    echo 1
  fi
}

setup() {
  set +e
  ANY_ERROR=0
  echo "Checking dependencies..."
  for tool in $DEPENDENCIES; do
    THIS_ERROR=$(_check_command_exists "$tool")
    if [[ $THIS_ERROR != "0" ]]; then
      if [[ $tool == "docker" ]]; then
        echo "ERROR: Please install Podman https://podman.io/ or Docker https://www.docker.com/"
      fi
      if [[ $tool == "jq" ]]; then
        echo "ERROR: Please install jq https://jqlang.org/"
      fi
      if [[ $tool == "mise" ]]; then
        echo "ERROR: Please install Mise https://mise.jdx.dev/"
      fi
    fi
    ANY_ERROR=$((ANY_ERROR + THIS_ERROR))
  done
  echo
  docker version || ANY_ERROR=$((ANY_ERROR + 1))
  jq --version || ANY_ERROR=$((ANY_ERROR + 1))
  mise version || ANY_ERROR=$((ANY_ERROR + 1))
  set -x
  mise exec node@$NODE_VERSION -- npm install --global @devcontainers/cli@$DEVCONTAINERS_VERSION
  set +x
  exit $ANY_ERROR
}

_devcontainer() {
  set -x
  mise exec node@$NODE_VERSION -- devcontainer "$@"
  set +x
}

new() {
  set +u
  DESTINATION_FOLDER="$3"
  if [[ -n $MOUNT_GIT_WORKTREE_COMMON_DIR ]] && [[ $MOUNT_GIT_WORKTREE_COMMON_DIR == "true" || $MOUNT_GIT_WORKTREE_COMMON_DIR == "1" ]]; then
    GIT_WORKTREE_ADD_ARGS="--relative-paths"
    DEVCONTAINER_UP_ARGS="--mount-git-worktree-common-dir"
  else
    GIT_WORKTREE_ADD_ARGS=""
    DEVCONTAINER_UP_ARGS=""
  fi
  set -u
  LOCAL_REPO="$1"
  if [[ ! -e $LOCAL_REPO || ! -e "$LOCAL_REPO/.git" ]]; then
    echo "ERROR: local path $LOCAL_REPO is not a git repo."
    exit 1
  else
    SAFE_BRANCH=$(echo "$2" | sed 's/[^a-zA-Z0-9-]/-/g' | cut -c1-50)
    pushd "$LOCAL_REPO"
    FOLDER_NAME=$(basename "$(pwd)")
    if [[ -z $DESTINATION_FOLDER ]]; then
      DESTINATION_FOLDER=../"$FOLDER_NAME.worktrees/$SAFE_BRANCH"
    fi

    DEFAULT_BRANCH=$(git rev-parse --abbrev-ref origin/HEAD | sed 's,origin/,,')
    git fetch origin "$DEFAULT_BRANCH"

    for count in 1 2; do
      echo "Attempt $count..."
      if [[ ! -e $DESTINATION_FOLDER ]]; then
        # add new branch or checkout existing
        git worktree add $GIT_WORKTREE_ADD_ARGS -b "$SAFE_BRANCH" "$DESTINATION_FOLDER" "origin/$DEFAULT_BRANCH" ||
          git worktree add $GIT_WORKTREE_ADD_ARGS "$DESTINATION_FOLDER" "$SAFE_BRANCH" || true
        if [[ ! -e $DESTINATION_FOLDER ]]; then
          # still no folder?
          git worktree prune
        fi
      fi
    done

    echo "Opening devcontainer"
    cp /Users/jon/code/cursor/bga/.devcontainer/devcontainer.json "$DESTINATION_FOLDER/.devcontainer/devcontainer.json"
    if type cksum &>/dev/null; then
      CKSUM_BIN="cksum"
    elif type md5 &>/dev/null; then
      CKSUM_BIN="md5"
    elif type sha1 &>/dev/null; then
      CKSUM_BIN="sha1"
    elif type sha1sum &>/dev/null; then
      CKSUM_BIN="sha1sum"
    fi
    OPENCODE_HOST_PORT=$(echo "$SAFE_BRANCH" | $CKSUM_BIN | sed 's/^[0-9]*\([0-9]\{5\}\).*/\1/g' | sed 's/^[567890]/4/')
    export OPENCODE_HOST_PORT
    echo "OPENCODE_HOST_PORT=$OPENCODE_HOST_PORT"

    CONTAINER_ID=$(_devcontainer up $DEVCONTAINER_UP_ARGS --workspace-folder "$DESTINATION_FOLDER" --remove-existing-container | jq -r '.containerId')
    HOST_PORT=$(docker inspect "$CONTAINER_ID" | jq -r '.[].HostConfig.PortBindings."4096/tcp".[].HostPort')
    echo "Opening browser"
    set -x
    open "http://127.0.0.1:$HOST_PORT"
    set +x
    echo "Starting OpenCode in devcontainer"
    set -x
    _devcontainer exec --workspace-folder "$DESTINATION_FOLDER" -- bash /opencode-serve.sh &
    set +x
  fi
}

set +u
COMMAND="$1"
case $COMMAND in
  setup)
    setup
    ;;
  new)
    new "$2" "$3"
    ;;
  help | *)
    help
    ;;
esac
