local marker = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/torus-calm"

_G.torus_calm_apply = function()
	local see = (torus.see or 1) * 0.5
	hl.config({
		decoration = {
			blur = { passes = 1, size = 4 },
			shadow = { range = 8 },
			glow = { enabled = false },
			motion_blur = { enabled = false },
			active_opacity = 1 - 0.10 * see,
			inactive_opacity = 1 - 0.25 * see,
		},
	})
end

local f = io.open(marker, "r")
if f then
	f:close()
	_G.torus_calm_apply()
end
