#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/state/torus" "$F/bin"
printf '#!/bin/sh\necho "fallback $*"\n' > "$F/bin/hyprland-share-picker"; chmod +x "$F/bin/hyprland-share-picker"
export XDG_STATE_HOME=$F/state PATH=$F/bin:$PATH
export XDPH_WINDOW_SHARING_LIST='11[HC>]discord[HT>]Discord[HE>]a1[HA>]42[HC>]cs2[HT>]Counter-Strike 2[HE>]b2[HA>]'
P=$REPO/home/.local/bin/torus-share-picker

assert_eq "fallback --allow-token" "$("$P" --allow-token)" "no request: the normal picker"
echo cs2 > "$F/state/torus/share-target"
assert_eq "[SELECTION]/window:42" "$("$P")" "game mode's request picks the game window"
[[ -e $F/state/torus/share-target ]] && fail "the request is used once"
assert_eq "fallback " "$("$P")" "the next share (Discord) gets the normal picker"
echo cs2 > "$F/state/torus/share-target"; touch -d '-1 minute' "$F/state/torus/share-target"
assert_eq "fallback " "$("$P")" "a stale request is ignored"
echo hl2_linux > "$F/state/torus/share-target"
assert_eq "fallback " "$("$P")" "no matching window: the normal picker"
echo "share-picker: ok"
