local see = math.max(0, math.min(1.5, tonumber(torus.read(torus.state .. "see-through", "1")) or 1))
torus.see = see
torus.opacity = function(active, inactive)
	local function f(x)
		return string.format("%.3f", 1 - (1 - x) * see)
	end
	return f(active) .. " " .. f(inactive) .. " 1"
end

hl.config({
	render = {
		cm_auto_hdr = 0,
	},
	general = {
		border_size = 2,
		gaps_in = 3,
		gaps_out = 8,
	},
	decoration = {
		rounding = 10,
		active_opacity = 1 - 0.10 * see,
		inactive_opacity = 1 - 0.25 * see,
		fullscreen_opacity = 1,
		dim_special = 0.3,
		blur = {
			enabled = true,
			size = 6,
			passes = 3,
			new_optimizations = true,
			ignore_opacity = true,
			xray = false,
			special = true,
		},
		shadow = {
			enabled = true,
			range = 18,
			render_power = 3,
			color = "rgba(11111bcc)",
		},
	},
})
