# bga

Just a simple script that:
1. Creates git worktree from a local git repo
2. Spawns a devcontainer in that git worktree
3. Runs OpenCode, coder/code-server in that container
4. Opens your browser to that OpenCode port
5. Opens your browser to that coder/code-server port

## Setup

Your project needs:
- `.devcontainer/` folder similar to the one in this repo
- `opencode.jsonc` or `opencode.json` file you can customize

Your machine needs:
- podman (or docker)
- podman-desktop (or docker-desktop)
- jq
- mise

## Usage

Something like this:

```shell
./path/to/bin/bga.sh setup
mkdir mycode
cd mycode
git clone ... myrepo1
./path/to/bin/bga.sh new ./myrepo1 feat-add-new-page
./path/to/bin/bga.sh new ./myrepo1 feat-change-login-form
git clone ... myrepo2
./path/to/bin/bga.sh new ./myrepo2 chore-adopt-infra-as-code
```

## License

MIT

## Why

Control where OpenCode runs and what it can access:

- git worktrees so that agents can't modify the `.git/hooks` that might run when a human uses `git`
- devcontainers so each opencode gets it's own environment and tools (and even versions of tools)
- reduces some prompt context since agents don't have to know about creating devcontainers themselves

## TODO / Not Implemented Yet

- File or git diff changes are not visible in the spawned OpenCode
  - this is because we used a light git worktree so the `.git` data is not available in the container.
  - this is by design so the agent cannot modify `.git/hooks/*`
  - current workaround is I used VSCode and it shows me all the git worktrees and changes in each.
  - in the future, I might consider a separate container without agents that has access to the `.git` data
  - maybe even automation to use GitHub App integration that will open PR
- API to list our spawned devcontainers that are running OpenCode
- Unfied web UI to list, re-open, open PR, delete, prune these devcontainers that are running OpenCode

## Out of Scope

- If you want OpenCode to access your host computer's files, then you don't need this. Just use OpenCode by itself.
- If you want OpenCode to be the controller and let agents decide when to use devcontainers, then you don't need this. Just use the opencode-devcontainers plugin with OpenCode.
