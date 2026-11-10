local repo, tmp = arg[1], arg[2]
local failures = 0
local function check(ok, msg)
	if not ok then
		io.stderr:write("FAIL: gameguard: " .. msg .. "\n")
		failures = failures + 1
	end
end

local monitors, handlers, timers, active
local function reset()
	monitors = { { name = "DP-1", x = 0, y = 1467 }, { name = "DP-2", x = 2560, y = 410 } }
	handlers, timers = {}, {}
	active = nil
end
local function mon(name)
	for _, m in ipairs(monitors) do
		if m.name == name then
			return m
		end
	end
end
local game = { class = "cs2", address = "0xabc", fullscreen = 2, mapped = true, monitor = { name = "DP-1" }, at = { 0, 1467 }, size = { 2560, 1440 } }

hl = {
	get_monitors = function()
		local out = {}
		for i, m in ipairs(monitors) do
			out[i] = { name = m.name, x = m.x, y = m.y }
		end
		return out
	end,
	monitor = function(o)
		local x, y = o.position:match("^(-?%d+)x(-?%d+)$")
		local m = mon(o.output)
		m.x, m.y = tonumber(x), tonumber(y)
	end,
	on = function(ev, fn)
		handlers[ev] = handlers[ev] or {}
		table.insert(handlers[ev], fn)
	end,
	timer = function(fn)
		table.insert(timers, fn)
	end,
	get_active_window = function()
		return active
	end,
	get_window = function()
		return active
	end,
	dispatch = function() end,
	dsp = { focus = function() end, cursor = { move = function() end } },
}
local function fire(ev, ...)
	for _, fn in ipairs(handlers[ev] or {}) do
		fn(...)
	end
end
local function run_timers()
	local t = timers
	timers = {}
	for _, fn in ipairs(t) do
		fn()
	end
end
local function load()
	handlers, timers = {}, {}
	dofile(repo .. "/home/.config/hypr/torus/gameguard.lua")
end

reset()
load()
fire("input.keyboard.key", 133, 0, 1)
check(#timers == 0, "SUPER without a game must not schedule anything")

active = game
fire("window.active", game)
check(mon("DP-2").x >= 50000, "focusing a fullscreen game moves the other screen away")

load()
check(mon("DP-2").x == 2560, "a config reload with the moat up puts the screen back at its real position, got " .. mon("DP-2").x)
run_timers()
check(mon("DP-2").x >= 50000, "after the reload the moat comes back for the game")

fire("input.keyboard.key", 133, 0, 1)
check(mon("DP-2").x == 2560, "SUPER lowers the moat")
local lock = os.getenv("XDG_RUNTIME_DIR") .. "/torus-lock/locked"
os.execute("mkdir -p '" .. os.getenv("XDG_RUNTIME_DIR") .. "/torus-lock' && : > '" .. lock .. "'")
run_timers()
check(mon("DP-2").x == 2560, "the moat must not go up while the session is locked")
os.remove(lock)
run_timers()
check(mon("DP-2").x >= 50000, "the moat comes back after unlock")

fire("window.close", game)
active = nil
check(mon("DP-2").x == 2560, "closing the game restores the screen")
local f = io.open(os.getenv("XDG_STATE_HOME") .. "/torus/gameguard-moat")
check(f == nil, "no saved moat left once it is down")

os.exit(failures == 0 and 0 or 1)
