#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
export HOME=$F XDG_CONFIG_HOME=$F/.config GIT_CONFIG_GLOBAL=$F/gitconfig GIT_CONFIG_NOSYSTEM=1
git config --global user.email t@example.invalid
git config --global user.name t
git config --global init.defaultBranch main
mk() { mkdir -p "$1" && git -C "$1" init -q && echo x > "$1/f" && git -C "$1" add f && git -C "$1" commit -qm init; }
mk "$F/dev/alpha"
git -C "$F/dev/alpha" remote add origin git@github.com:someone/alpha.git
echo dirty >> "$F/dev/alpha/f"; echo new > "$F/dev/alpha/g"
mk "$F/dev/priv/beta"
git -C "$F/dev/priv/beta" remote add origin https://user:s3cret@gitlab.example/team/beta.git
mk "$F/dev/node_modules/gamma"
mk "$F/dev/priv/delta"
git -C "$F/dev/priv/delta" remote add origin ssh://git@code.example:2222/me/delta
git -C "$F/dev/alpha" worktree add -q -b feat "$F/dev/alpha-wt"
mkdir -p "$F/other"; mk "$F/other/epsilon"

out=$("$REPO/home/.local/bin/torus-projects")
assert_eq "$F/dev/alpha	main	2	https://github.com/someone/alpha" "$(grep "^$F/dev/alpha	" <<< "$out")" "dirty repo with ssh remote"
assert_eq "$F/dev/alpha-wt	feat	0	https://github.com/someone/alpha" "$(grep "^$F/dev/alpha-wt	" <<< "$out")" "worktree"
assert_eq "$F/dev/priv/beta	main	0	https://gitlab.example/team/beta" "$(grep "/beta	" <<< "$out")" "credentials stripped"
assert_eq "$F/dev/priv/delta	main	0	https://code.example/me/delta" "$(grep "/delta	" <<< "$out")" "ssh:// url"
grep -q gamma <<< "$out" && fail "node_modules skipped"
grep -q epsilon <<< "$out" && fail "only ~/dev by default"
grep -q s3cret <<< "$out" && fail "secret leaked"
[[ -z $(git -C "$F/dev/alpha" status --porcelain | grep index.lock || true) ]] || fail "index lock"

mkdir -p "$F/.config/torus"; printf '# roots\n~/other\n' > "$F/.config/torus/projects"
out=$("$REPO/home/.local/bin/torus-projects")
assert_eq "$F/other/epsilon	main	0	" "$out" "roots from the config"
