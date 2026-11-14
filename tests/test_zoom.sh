#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

lua - "$REPO" <<'L' || fail "zoom steps"
local repo = arg[1]
local zoom, execs, sets = 1, {}, 0
hl = {
	get_config = function(k)
		assert(k == "cursor:zoom_factor")
		return zoom
	end,
	config = function(c)
		zoom = c.cursor.zoom_factor
		sets = sets + 1
	end,
	exec_cmd = function(c)
		execs[#execs + 1] = c
	end,
}
torus = {}
dofile(repo .. "/home/.config/hypr/torus/zoom.lua")
local z = torus.zoom
local bad = 0
local function eq(want, got, msg)
	if want ~= got then
		io.stderr:write("FAIL: " .. msg .. ": want " .. tostring(want) .. " got " .. tostring(got) .. "\n")
		bad = bad + 1
	end
end
eq("1,1.5,2,3,4", table.concat(z.steps, ","), "step list")
local up, down = z.by(1), z.by(-1)
local seen = {}
for _ = 1, 6 do
	up()
	seen[#seen + 1] = zoom
end
eq("1.5,2,3,4,4,4", table.concat(seen, ","), "scroll up climbs and stops at 4x")
seen = {}
for _ = 1, 6 do
	down()
	seen[#seen + 1] = zoom
end
eq("3,2,1.5,1,1,1", table.concat(seen, ","), "scroll down goes back to 1x and stays")
eq(8, sets, "no config write when the level does not change")
eq("qs -c torus ipc call torus zoomShow 1", execs[#execs], "the island hears the last level")
z.toggle()
eq(2, zoom, "toggle from 1x is 2x")
z.toggle()
eq(1, zoom, "toggle back is 1x")
zoom = 3
z.toggle()
eq(1, zoom, "toggle from any zoom leaves it")
zoom = 2.5
up()
eq(3, zoom, "an odd level steps to the next one up")
os.exit(bad == 0 and 0 or 1)
L
grep -q 'dofile(dir .. "zoom.lua")' "$REPO/home/.config/hypr/hyprland.lua" || fail "zoom.lua loads before the binds"
echo "zoom: ok"
