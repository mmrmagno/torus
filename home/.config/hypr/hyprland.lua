local home = os.getenv("HOME")
local dir = home .. "/.config/hypr/torus/"
local state = (os.getenv("XDG_STATE_HOME") or (home .. "/.local/state")) .. "/torus/"

local function read(path, default)
	local f = io.open(path, "r")
	if not f then
		return default
	end
	local v = f:read("*l")
	f:close()
	return (v and v ~= "") and v or default
end

torus = {
	dir = dir,
	state = state,
	vm = os.getenv("TORUS_VM") == "1",
	read = read,
}

dofile(dir .. "env.lua")
dofile(dir .. "input.lua")
dofile(dir .. "look.lua")
dofile(dir .. "animations/" .. read(state .. "animations", "fancy") .. ".lua")
pcall(dofile, state .. "theme/hypr-colors.lua")
dofile(dir .. "rules.lua")
pcall(dofile, home .. "/.config/hypr/rules.local.lua")
dofile(dir .. "binds.lua")
dofile(dir .. "autostart.lua")
pcall(dofile, home .. "/.config/hypr/monitors.lua")
