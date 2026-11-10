#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/home/.cache/torus" "$F/state/torus" "$F/run"
printf 'cs2\tcursor\n' > "$F/state/torus/rules.tsv"
HOME=$F/home XDG_STATE_HOME=$F/state XDG_RUNTIME_DIR=$F/run lua "$REPO/tests/gameguard/harness.lua" "$REPO" "$F" || fail "gameguard harness"
