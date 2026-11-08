hl.config({
	general = {
		border_size = 2,
		gaps_in = 3,
		gaps_out = 8,
	},
	decoration = {
		rounding = 10,
		active_opacity = 0.90,
		inactive_opacity = 0.75,
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
