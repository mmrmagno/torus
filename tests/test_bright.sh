#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

F=$(mktemp -d)
trap 'rm -rf "$F"' EXIT
mkdir -p "$F/bin" "$F/run"
export STUB_LOG=$F/calls XDG_RUNTIME_DIR=$F/run VCP=$F/vcp
printf '4 60\n7 30\n' > "$VCP"
cat > "$F/bin/ddcutil" <<'S'
#!/usr/bin/env bash
echo "ddcutil $*" >> "$STUB_LOG"
case " $* " in
  *" detect "*)
    printf 'Display 1\n   I2C bus:  /dev/i2c-4\n   DRM connector:  card1-DP-1\n   Monitor:  AUS:VG27AQ1A:L5LM\n\nDisplay 2\n   I2C bus:  /dev/i2c-7\n   DRM connector:  card1-DP-2\n   Monitor:  AOC:Q27G2WG4:F8F\n' ;;
  *" getvcp 10 "*) b=$(sed -n 's/.*--bus \([0-9]*\).*/\1/p' <<< "$*"); printf 'VCP 10 C %s 100\n' "$(awk -v b="$b" '$1 == b {print $2}' "$VCP")" ;;
  *" setvcp 10 "*) b=$(sed -n 's/.*--bus \([0-9]*\).*/\1/p' <<< "$*"); v=$(sed -n 's/.*setvcp 10 \([0-9]*\).*/\1/p' <<< "$*"); awk -v b="$b" -v v="$v" '$1 == b {$2 = v} {print}' "$VCP" > "$VCP.new" && mv "$VCP.new" "$VCP" ;;
esac
S
printf '#!/usr/bin/env bash\necho "hyprctl $*" >> "$STUB_LOG"\necho '"'"'[{"name":"DP-1","focused":false},{"name":"DP-2","focused":true}]'"'"'\n' > "$F/bin/hyprctl"
printf '#!/usr/bin/env bash\necho "qs $*" >> "$STUB_LOG"\n' > "$F/bin/qs"
chmod +x "$F/bin"/*
export PATH=$F/bin:$PATH
T=$REPO/home/.local/bin/torus-bright

assert_eq "$(printf 'DP-1 60\nDP-2 30')" "$("$T" list)" "list: every monitor with its brightness"
"$T" list > /dev/null
assert_eq 1 "$(grep -c 'ddcutil.*detect' "$STUB_LOG")" "detect runs once per session"

: > "$STUB_LOG"
"$T" up
assert_eq "35" "$(awk '$1 == 7 {print $2}' "$VCP")" "up: focused monitor +5"
assert_eq "60" "$(awk '$1 == 4 {print $2}' "$VCP")" "up: other monitor untouched"
grep -q 'qs -c torus ipc call torus brightnessOsd 35' "$STUB_LOG" || fail "island shows the level"

"$T" set DP-1 120
assert_eq "100" "$(awk '$1 == 4 {print $2}' "$VCP")" "set clamps to 100"
for _ in $(seq 10); do "$T" down > /dev/null; done
assert_eq "0" "$(awk '$1 == 7 {print $2}' "$VCP")" "down clamps to 0"

rc=0; PATH=/usr/bin:/bin "$T" list > /dev/null 2>&1 || rc=$?
[[ -x /usr/bin/ddcutil ]] || assert_eq 3 "$rc" "no ddcutil exits 3"
true
