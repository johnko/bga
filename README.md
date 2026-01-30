# bga

Just a simple script that:
1. Creates git worktree from a local git repo
2. Spawns a devcontainer in that git worktree
3. Runs OpenCode in that container
4. Opens your browser to that OpenCode port

## Setup

Your project needs:
- `.devcontainer/` folder similar to the one in this repo
- `opencode.jsonc` or `opencode.json` file you can customize

Your machine needs:
- docker
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
