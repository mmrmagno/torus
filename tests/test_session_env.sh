#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

command -v lua > /dev/null || { echo "session env: skipped (no lua)"; exit 0; }
out=$(HOME=/nonexistent lua - "$REPO/home/.config/hypr/torus" <<'LUA'
local dir = arg[1] .. "/"
local names, handlers, cmds = {}, {}, {}
hl = {
  env = function(k) names[#names + 1] = k end,
  on = function(ev, f) handlers[ev] = f end,
  exec_cmd = function(c) cmds[#cmds + 1] = c end,
}
torus = { dir = dir, state = "/nonexistent/", read = function(_, d) return d end }
dofile(dir .. "env.lua")
dofile(dir .. "autostart.lua")
handlers["hyprland.start"]()
for _, n in ipairs(names) do print("env " .. n) end
for _, c in ipairs(cmds) do print("cmd " .. c) end
LUA
)
imp=$(grep -m1 '^cmd .*import-environment' <<< "$out") || fail "no import-environment at start"
for n in $(sed -n 's/^env //p' <<< "$out") WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE; do
  grep -qE "import-environment[^&;]* $n( |&|;|')" <<< "$imp" || fail "$n is set for Hyprland but not given to the shell and the apps it starts: $imp"
done
grep -q 'import-environment.*&& systemctl --user restart torus-shell' <<< "$imp" || fail "the shell restarts only after the import"
echo "session env: ok"
