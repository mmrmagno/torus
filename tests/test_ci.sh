#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin" "$F/run" "$F/repo"
export PATH=$F/bin:$PATH XDG_RUNTIME_DIR=$F/run LOG=$F/calls TORUS_CI_WAIT=10 TORUS_CI_INTERVAL=1
git -C "$F/repo" init -q -b main && git -C "$F/repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m x
cat > "$F/bin/gh" <<'S'
#!/usr/bin/env bash
echo "gh $*" >> "$LOG"
case "$1 $2" in
  "repo view") echo me/proj ;;
  "run list") echo 42 ;;
  "run watch") exit 1 ;;
  "run view") echo "${STUB_CONCLUSION:-failure} Build_and_test https://github.com/me/proj/actions/runs/42" ;;
esac
S
printf '#!/bin/sh\necho "notify $*" >> "$LOG"\n' > "$F/bin/notify-send"
chmod +x "$F"/bin/*
C=$REPO/home/.local/bin/torus-ci
"$C" "$F/repo"
grep -q "gh run list -R me/proj --commit $(git -C "$F/repo" rev-parse HEAD)" "$LOG" || fail "finds the run of the pushed commit"
grep -q "notify -a GitHub Actions -i dialog-error -A open=Open CI failed · proj Build and test on main" "$LOG" || fail "failure notified: $(cat "$LOG")"
: > "$LOG"
STUB_CONCLUSION=success "$C" "$F/repo"
grep -q "CI passed · proj" "$LOG" || fail "success notified"
mkdir "$F/run/torus-ci-$(git -C "$F/repo" rev-parse HEAD)"
: > "$LOG"
"$C" "$F/repo"
grep -q "run watch" "$LOG" && fail "a second watcher for the same commit must not start"
grep -q 'torus_ci_post' "$REPO/home/.config/zsh/conf.d/torus.zsh" || fail "zsh hook installed"
echo "ci: ok"
