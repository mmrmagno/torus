#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
X=$REPO/sddm/xsetup
mkedid "$F/a" VG27AQ1A
mkedid "$F/b" Q27G2WG4
mkedid "$F/c" UNKNOWN1

assert_eq Q27G2WG4 "$("$X" --edid-name "$F/b")" "name from an edid file"

hexblock() { od -An -tx1 -v "$1" | tr -d ' \n' | fold -w32 | sed 's/^/\t\t/'; }
{
  echo "Screen 0: minimum 320 x 200, current 5120 x 1440, maximum 16384 x 16384"
  echo "DisplayPort-0 connected primary 2560x1440+0+0 (normal left inverted right x axis y axis) 597mm x 336mm"
  printf '\tEDID: \n'; hexblock "$F/a"
  printf '\tnon-desktop: 0\n   2560x1440     59.95*+\n'
  echo "DisplayPort-1 connected 2560x1440+2560+0 (normal left inverted right x axis y axis) 597mm x 336mm"
  printf '\tEDID: \n'; hexblock "$F/b"
  echo "HDMI-A-0 connected 1920x1080+5120+0 (normal left inverted right x axis y axis) 0mm x 0mm"
  printf '\tEDID: \n'; hexblock "$F/c"
  echo "DisplayPort-2 disconnected (normal left inverted right x axis y axis)"
} > "$F/prop"
mkdir -p "$F/bin"
printf '#!/usr/bin/env bash\nif [[ $1 == --prop ]]; then cat "%s"; else echo "xrandr $*" >> "%s"; fi\n' "$F/prop" "$F/calls" > "$F/bin/xrandr"
chmod +x "$F/bin/xrandr"
printf 'Q27G2WG4 3 2560 410\nVG27AQ1A 0 0 1467\n' > "$F/monitors"

PATH=$F/bin:$PATH TORUS_SDDM_MONITORS=$F/monitors TORUS_SDDM_NEXT=/bin/true "$X"
assert_contains "$F/calls" "xrandr --output DisplayPort-1 --rotate left --pos 2560x410"
assert_contains "$F/calls" "xrandr --output DisplayPort-0 --rotate normal --pos 0x1467"
grep -q 'HDMI-A-0' "$F/calls" && fail "unknown monitor must be left alone"

rm "$F/calls"
PATH=$F/bin:$PATH TORUS_SDDM_MONITORS=$F/missing TORUS_SDDM_NEXT=/bin/true "$X"
[[ -e $F/calls ]] && fail "no monitor file means no xrandr changes"
{
  echo "DisplayPort-1 connected 2560x1440+0+0 (normal left inverted right x axis y axis) 597mm x 336mm"
  printf '\tEDID: \n'; hexblock "$F/b"
} > "$F/prop"
PATH=$F/bin:$PATH TORUS_SDDM_MONITORS=$F/monitors TORUS_SDDM_NEXT=/bin/true "$X"
assert_contains "$F/calls" "xrandr --output DisplayPort-1 --rotate left --pos 2560x410"
true
