local home = os.getenv("HOME")
local state = (os.getenv("XDG_STATE_HOME") or (home .. "/.local/state")) .. "/torus/"
local moatfile = state .. "gameguard-moat"
local lockfile = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/torus-lock/locked"
local logfile = home .. "/.cache/torus/gameguard.log"
local FAR = 100000

_G.torus_guard_gen = (_G.torus_guard_gen or 0) + 1
local gen = _G.torus_guard_gen
local guard = { addr = nil, released = false, ticket = 0, moat = nil }

local function log(msg)
	local f = io.open(logfile, "a")
	if f then
		f:write(os.date("%H:%M:%S ") .. msg .. "\n")
		f:close()
	end
end

local function exists(path)
	local f = io.open(path, "r")
	if f then
		f:close()
		return true
	end
	return false
end

local function locked()
	return exists(lockfile)
end

local function gamemode()
	local f = io.open(state .. "gamemode", "r")
	if not f then
		return "off"
	end
	local v = f:read("*l") or "off"
	f:close()
	return v
end

_G.torus_gamemode_apply = function()
	hl.config({
		animations = { enabled = false },
		decoration = { blur = { enabled = false }, shadow = { enabled = false }, wobble = { enabled = false }, motion_blur = { enabled = false }, glow = { enabled = false }, rounding = 0 },
		general = { gaps_in = 0, gaps_out = 0, border_size = 1 },
	})
end

local function listed()
	local out = {}
	local f = io.open(state .. "rules.tsv", "r")
	if not f then
		return out
	end
	for line in f:lines() do
		local class, kind = line:match("^([^\t]+)\t([^\t]+)")
		if kind == "cursor" then
			out[class] = true
		end
	end
	f:close()
	return out
end
local cursor_rules = listed()

local function is_game(w)
	if not w or not w.class then
		return false
	end
	local c = w.class
	return c == "gamescope" or c:match("^steam_app_%d+$") ~= nil or cursor_rules[c] == true
end

local function xy(v)
	if type(v) ~= "table" then
		return 0, 0
	end
	return v.x or v[1] or 0, v.y or v[2] or 0
end

-- the real positions live on disk, so a reload or a crash can always put the screens back
local function read_moat()
	local f = io.open(moatfile, "r")
	if not f then
		return nil
	end
	local out = {}
	for line in f:lines() do
		local name, x, y = line:match("^(%S+)\t(-?%d+)\t(-?%d+)$")
		if name then
			out[#out + 1] = { name = name, x = tonumber(x), y = tonumber(y) }
		end
	end
	f:close()
	return #out > 0 and out or nil
end

local function write_moat(moved)
	local f = io.open(moatfile .. ".tmp", "w")
	if not f then
		return
	end
	for _, m in ipairs(moved) do
		f:write(m.name .. "\t" .. math.floor(m.x) .. "\t" .. math.floor(m.y) .. "\n")
	end
	f:close()
	os.rename(moatfile .. ".tmp", moatfile)
end

local function game()
	if not guard.addr then
		return nil
	end
	local w = hl.get_window("address:" .. guard.addr)
	if not w or not w.mapped or (w.fullscreen or 0) == 0 then
		guard.addr = nil
		return nil
	end
	return w
end

local function raise_moat(g, why)
	if guard.moat or not g.monitor then
		return
	end
	if locked() then
		log("moat skipped (" .. why .. "): session locked")
		return
	end
	local moved = {}
	for _, m in ipairs(hl.get_monitors()) do
		if m.name ~= g.monitor.name and m.x < FAR / 2 then
			moved[#moved + 1] = { name = m.name, x = m.x, y = m.y }
		end
	end
	if #moved == 0 then
		return
	end
	write_moat(moved)
	guard.moat = moved
	log("moat up (" .. why .. ") for " .. tostring(g.class))
	for i, m in ipairs(moved) do
		hl.monitor({ output = m.name, position = (m.x + FAR * i) .. "x" .. m.y })
	end
end

local function lower_moat(why)
	local moved = guard.moat or read_moat()
	guard.moat = nil
	os.remove(moatfile)
	if not moved then
		return
	end
	log("moat down (" .. why .. ")")
	for _, m in ipairs(moved) do
		hl.monitor({ output = m.name, position = m.x .. "x" .. m.y })
	end
end

local function recheck()
	if gen ~= _G.torus_guard_gen or guard.released then
		return
	end
	if locked() then
		hl.timer(recheck, { timeout = 2500, type = "oneshot" })
		return
	end
	local w = hl.get_active_window()
	if is_game(w) and (w.fullscreen or 0) ~= 0 then
		guard.addr = w.address
		raise_moat(w, "back in the game")
	end
end

-- SUPER and alt-tab open a 2.5 s window where the screens are back and focus can leave the game
_G.torus_guard_release = function(why)
	if gen ~= _G.torus_guard_gen or (not guard.moat and not guard.addr) then
		return
	end
	guard.released = true
	guard.ticket = guard.ticket + 1
	local mine = guard.ticket
	lower_moat(why or "alt-tab")
	hl.timer(function()
		if gen ~= _G.torus_guard_gen or mine ~= guard.ticket then
			return
		end
		guard.released = false
		recheck()
	end, { timeout = 2500, type = "oneshot" })
end

hl.on("input.keyboard.key", function(code, _, pressed)
	if pressed ~= 0 and (code == 133 or code == 134) and _G.torus_guard_release then
		_G.torus_guard_release("super key")
	end
end)

hl.on("window.active", function(w)
	if gen ~= _G.torus_guard_gen then
		return
	end
	if w and is_game(w) and (w.fullscreen or 0) ~= 0 then
		guard.addr = w.address
		if gamemode() == "off" then
			local cls = w.class or ""
			hl.exec_cmd("torus-gamemode auto-on " .. (cls:match("^[%w_.-]+$") and cls or ""))
		end
		if not guard.released then
			raise_moat(w, "game focused")
		end
		return
	end
	local g = game()
	if w and g and g.monitor and w.monitor and g.monitor.name == w.monitor.name then
		guard.addr = nil
		lower_moat("another window on the game screen")
	end
end)

hl.on("window.fullscreen", function(w)
	if gen == _G.torus_guard_gen and w and guard.addr == w.address and (w.fullscreen or 0) == 0 then
		lower_moat("game left fullscreen")
		hl.exec_cmd("torus-gamemode auto-off")
	end
end)

hl.on("window.close", function(w)
	if gen == _G.torus_guard_gen and w and guard.addr == w.address then
		guard.addr = nil
		lower_moat("game closed")
		hl.exec_cmd("torus-gamemode auto-off")
	end
end)

hl.on("monitor.focused", function(m)
	if gen ~= _G.torus_guard_gen or guard.released or locked() then
		return
	end
	local g = game()
	if not g or not m or not g.monitor or g.monitor.name == m.name then
		return
	end
	local ax, ay = xy(g.at)
	local sw, sh = xy(g.size)
	hl.dispatch(hl.dsp.focus({ window = "address:" .. g.address }))
	hl.dispatch(hl.dsp.cursor.move({ x = math.floor(ax + sw / 2), y = math.floor(ay + sh / 2) }))
end)

if gamemode() ~= "off" then
	_G.torus_gamemode_apply()
end
if read_moat() then
	lower_moat("config load")
end
local current = hl.get_active_window()
if is_game(current) and (current.fullscreen or 0) ~= 0 then
	guard.addr = current.address
	hl.timer(recheck, { timeout = 1000, type = "oneshot" })
end
