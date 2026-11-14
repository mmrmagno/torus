local steps = { 1, 1.5, 2, 3, 4 }

local function step(cur, dir)
	if dir > 0 then
		for _, s in ipairs(steps) do
			if s > cur + 0.01 then
				return s
			end
		end
		return steps[#steps]
	end
	for i = #steps, 1, -1 do
		if steps[i] < cur - 0.01 then
			return steps[i]
		end
	end
	return steps[1]
end

local function current()
	return tonumber(hl.get_config("cursor:zoom_factor")) or 1
end

local function set(z)
	if math.abs(z - current()) < 0.01 then
		return
	end
	hl.config({ cursor = { zoom_factor = z } })
	hl.exec_cmd("qs -c torus ipc call torus zoomShow " .. z)
end

torus.zoom = {
	steps = steps,
	step = step,
	by = function(dir)
		return function()
			set(step(current(), dir))
		end
	end,
	toggle = function()
		set(current() > 1.01 and 1 or 2)
	end,
}
