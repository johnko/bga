#!/usr/bin/env bash
set -euo pipefail

# renovate: datasource=github-releases depName=nodejs/node packageName=nodejs/node
NODE_VERSION=24.13.0

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
  list                            List devcontainers and their
                                  OpenCode, coder/code-server URLs.
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
  if [[ $ANY_ERROR != "0" ]]; then
    exit $ANY_ERROR
  fi
}

_silent_check() {
  for tool in $DEPENDENCIES; do
    type "$tool" &>/dev/null || setup
  done
  # also check if devcontainer cli is available
  mise exec node@$NODE_VERSION -- type devcontainer &>/dev/null || setup
}

_devcontainer() {
  set -x
  mise exec node@$NODE_VERSION -- devcontainer "$@"
  set +x
}

_check_and_open_url() {
  URL="$1"
  echo "Checking port for $URL"
  if type wget &>/dev/null; then
    CURL_BIN="wget --timeout=5 --quiet --output-document=-"
  elif type curl &>/dev/null; then
    CURL_BIN="curl --connect-timeout 5 --fail --silent --output -"
  fi
  set +e
  CURL_EXIT_CODE=500
  for _ in $(seq 1 60); do
    # echo "CURL_EXIT_CODE=$CURL_EXIT_CODE"
    if [[ $CURL_EXIT_CODE != "0" ]]; then
      $CURL_BIN "$URL" &>/dev/null
      CURL_EXIT_CODE=$?
      sleep 1
    fi
  done
  set -e

  echo "Opening browser to $URL"
  set -x
  open "$URL"
  set +x
}

new() {
  _silent_check
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

    for _ in 1 2; do
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
    if type cksum &>/dev/null; then
      CKSUM_BIN="cksum"
    elif type md5 &>/dev/null; then
      CKSUM_BIN="md5"
    elif type md5sum &>/dev/null; then
      CKSUM_BIN="md5sum"
    elif type sha1 &>/dev/null; then
      CKSUM_BIN="sha1"
    elif type sha1sum &>/dev/null; then
      CKSUM_BIN="sha1sum"
    fi
    OPENCODE_HOST_PORT=$(echo "$SAFE_BRANCH" | $CKSUM_BIN | sed -e 's/[^0-9]//g' -e 's/^[0-9]*\([0-9]\{5\}\).*/\1/g' -e 's/^[0-9]/4/')
    # OPENCODE_HOST_PORT is used in devcontainer.json used by devcontainer up to pin to a consistent host port per branch
    # and bind to localhost/127.0.0.1 which is safter than --publish-all
    export OPENCODE_HOST_PORT
    echo "OPENCODE_HOST_PORT=$OPENCODE_HOST_PORT"
    CODER_HOST_PORT=$(echo "$SAFE_BRANCH" | $CKSUM_BIN | sed -e 's/[^0-9]//g' -e 's/^[0-9]*\([0-9]\{5\}\).*/\1/g' -e 's/^[0-9]/3/')
    # CODER_HOST_PORT is used in devcontainer.json used by devcontainer up to pin to a consistent host port per branch
    # and bind to localhost/127.0.0.1 which is safter than --publish-all
    export CODER_HOST_PORT
    echo "CODER_HOST_PORT=$CODER_HOST_PORT"

    # CONTAINER_ID=$()
    _devcontainer up $DEVCONTAINER_UP_ARGS --workspace-folder "$DESTINATION_FOLDER" --remove-existing-container | jq -r '.containerId'
    # DETECTED_PORT=$(docker inspect "$CONTAINER_ID" | jq -r '.[].HostConfig.PortBindings."4096/tcp".[].HostPort')
    OPENCODE_URL="http://127.0.0.1:$OPENCODE_HOST_PORT"
    CODER_URL="http://127.0.0.1:$CODER_HOST_PORT"

    _check_and_open_url "$OPENCODE_URL"
    _check_and_open_url "$CODER_URL"
  fi
}

list() {
  echo 'HINT: In macOS, you can "Cmd + Double Click" on the URLs.'
  echo
  (
    echo "NAME FOLDER OPENCODE_URL CODER_URL"
    JSON_ALL_DEVCONTAINERS=$(docker ps --filter 'label=devcontainer.local_folder' --format '{{json}}')
    for id in $(echo "$JSON_ALL_DEVCONTAINERS" | jq -r '.[].Id'); do
      # echo "# $id"
      ITEM_NAME=$(echo "$JSON_ALL_DEVCONTAINERS" | jq -r ".[] | select(.Id == \"$id\") | .Names[0]")
      ITEM_FOLDER=$(echo "$JSON_ALL_DEVCONTAINERS" | jq -r ".[] | select(.Id == \"$id\") | .Labels.\"devcontainer.local_folder\"")
      ITEM_OPENCODE_HOST_PORT=$(echo "$JSON_ALL_DEVCONTAINERS" | jq -r ".[] | select(.Id == \"$id\") | .Ports[] | select(.container_port == 4096) | .host_port")
      ITEM_CODER_HOST_PORT=$(echo "$JSON_ALL_DEVCONTAINERS" | jq -r ".[] | select(.Id == \"$id\") | .Ports[] | select(.container_port == 8080) | .host_port")
      ITEM_OPENCODE_URL="http://127.0.0.1:$ITEM_OPENCODE_HOST_PORT"
      ITEM_CODER_URL="http://127.0.0.1:$ITEM_CODER_HOST_PORT"
      echo "$ITEM_NAME $ITEM_FOLDER $ITEM_OPENCODE_URL $ITEM_CODER_URL"
    done
  ) | column -t
}

set +u
COMMAND="$1"
case $COMMAND in
  setup | install)
    setup
    ;;
  new | create)
    new "$2" "$3"
    ;;
  list | ls | ps)
    list
    ;;
  help | *)
    help
    ;;
esac
