local state = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/torus/"
local guard = { addr = nil, allow_until = 0 }

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

hl.on("input.keyboard.key", function(code, _, pressed)
	-- super and alt mean the user is leaving on purpose (alt-tab, workspace keys)
	if pressed ~= 0 and (code == 133 or code == 134 or code == 64 or code == 108) then
		guard.allow_until = os.time() + 2
	end
end)

hl.on("window.active", function(w)
	if not w then
		return
	end
	if is_game(w) and (w.fullscreen or 0) ~= 0 then
		guard.addr = w.address
		return
	end
	local g = game()
	if g and g.monitor and w.monitor and g.monitor.name == w.monitor.name then
		guard.addr = nil
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
end
