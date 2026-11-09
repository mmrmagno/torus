local home = os.getenv("HOME")
local state = (os.getenv("XDG_STATE_HOME") or (home .. "/.local/state")) .. "/torus/"
local guard = { addr = nil, allow_until = 0, moat = nil }
local logfile = home .. "/.cache/torus/gameguard.log"

local function log(msg)
	local f = io.open(logfile, "a")
	if f then
		f:write(os.date("%H:%M:%S ") .. msg .. "\n")
		f:close()
	end
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

local function is_game(w)
	if not w or not w.class then
		return false
	end
	local c = w.class
	return c == "gamescope" or c:match("^steam_app_%d+$") ~= nil or listed()[c] == true
end

local function xy(v)
	if type(v) ~= "table" then
		return 0, 0
	end
	return v.x or v[1] or 0, v.y or v[2] or 0
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

-- other monitors move far away while a game is focused, so the cursor has no edge to cross
local function raise_moat(g, why)
	if guard.moat or not g.monitor then
		return
	end
	log("moat up (" .. why .. ") for " .. tostring(g.class))
	local moved = {}
	local i = 0
	for _, m in ipairs(hl.get_monitors()) do
		if m.name ~= g.monitor.name then
			i = i + 1
			moved[#moved + 1] = { name = m.name, x = m.x, y = m.y }
			hl.monitor({ output = m.name, position = (m.x + 100000 * i) .. "x" .. m.y })
		end
	end
	guard.moat = moved
end

local function lower_moat(why)
	if not guard.moat then
		return
	end
	local moved = guard.moat
	guard.moat = nil
	log("moat down (" .. why .. ")")
	for _, m in ipairs(moved) do
		hl.monitor({ output = m.name, position = m.x .. "x" .. m.y })
	end
end

local function recheck()
	local w = hl.get_active_window()
	if is_game(w) and (w.fullscreen or 0) ~= 0 then
		guard.addr = w.address
		raise_moat(w, "back in the game")
	end
end

_G.torus_guard_release = function(why)
	guard.allow_until = os.time() + 2
	lower_moat(why or "alt-tab")
	hl.timer(recheck, { timeout = 2500, type = "oneshot" })
end

hl.on("input.keyboard.key", function(code, _, pressed)
	if pressed ~= 0 and (code == 133 or code == 134) then
		_G.torus_guard_release("super key")
	end
end)

hl.on("window.active", function(w)
	if w and is_game(w) and (w.fullscreen or 0) ~= 0 then
		guard.addr = w.address
		if os.time() >= guard.allow_until then
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
	if w and guard.addr == w.address and (w.fullscreen or 0) == 0 then
		lower_moat("game left fullscreen")
	end
end)

hl.on("window.close", function(w)
	if w and guard.addr == w.address then
		guard.addr = nil
		lower_moat("game closed")
	end
end)

hl.on("monitor.focused", function(m)
	local g = game()
	if not g or not m or not g.monitor or g.monitor.name == m.name or os.time() < guard.allow_until then
		return
	end
	local ax, ay = xy(g.at)
	local sw, sh = xy(g.size)
	hl.dispatch(hl.dsp.focus({ window = "address:" .. g.address }))
	hl.dispatch(hl.dsp.cursor.move({ x = math.floor(ax + sw / 2), y = math.floor(ay + sh / 2) }))
end)

local current = hl.get_active_window()
if is_game(current) and (current.fullscreen or 0) ~= 0 then
	guard.addr = current.address
	raise_moat(current, "config load")
end
