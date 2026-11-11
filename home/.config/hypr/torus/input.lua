hl.config({
	input = {
		kb_layout = "us, us, ch, eu",
		kb_variant = ", dvorak,,",
		accel_profile = "flat",
		numlock_by_default = true,
		follow_mouse = 1,
		touchpad = {
			natural_scroll = false,
			tap_to_click = true,
			disable_while_typing = true,
			clickfinger_behavior = true,
		},
	},
	dwindle = {
		preserve_split = true,
	},
	master = {
		new_status = "master",
	},
	general = {
		layout = "dwindle",
		resize_on_border = true,
		snap = {
			enabled = true,
			window_gap = 1,
			respect_gaps = true,
		},
	},
	misc = {
		vrr = 0,
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
		force_default_wallpaper = 0,
		anr_missed_pings = 5,
		allow_session_lock_restore = true,
	},
	xwayland = {
		force_zero_scaling = true,
	},
	ecosystem = {
		no_donation_nag = true,
		no_update_news = true,
	},
	cursor = {
		no_hardware_cursors = torus.vm,
	},
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 4, direction = "up", action = function() hl.exec_cmd("qs -c torus ipc call torus overviewToggle") end })
hl.gesture({ fingers = 4, direction = "down", action = function() hl.exec_cmd("qs -c torus ipc call torus dashboardToggle") end })
