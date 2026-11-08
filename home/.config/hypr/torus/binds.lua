local MOD = "SUPER"

local function ipc(fn, arg)
	return "qs -c torus ipc call torus " .. fn .. (arg and (" " .. arg) or "")
end

local function bind(keys, action, description, opts)
	local o = opts or {}
	o.description = description
	hl.bind(keys, type(action) == "string" and hl.dsp.exec_cmd(action) or action, o)
end

local locked = { locked = true }
local locked_repeat = { locked = true, repeating = true }
local repeating = { repeating = true }

local function cycle_fullscreen()
	local w = hl.get_active_window()
	if not w then
		return
	end
	local next_state = ((tonumber(w.fullscreen) or 0) + 1) % 3
	hl.dispatch(hl.dsp.window.fullscreen_state({ internal = next_state, client = next_state, window = w }))
end

local function move_window(dir, pix)
	local lut = { l = { -1, 0 }, r = { 1, 0 }, u = { 0, -1 }, d = { 0, 1 } }
	local m = lut[dir]
	return function()
		local w = hl.get_active_window()
		if not w then
			return
		end
		local args = w.floating and { x = m[1] * pix, y = m[2] * pix, relative = true } or { direction = dir }
		hl.dispatch(hl.dsp.window.move(args))
	end
end

bind(MOD .. " + T", "kitty", "[Launcher|Apps] terminal emulator")
bind(MOD .. " + ALT + T", "torus-dropdown", "[Launcher|Apps] dropdown terminal")
bind(MOD .. " + E", "dolphin", "[Launcher|Apps] file explorer")
bind(MOD .. " + F", "zen", "[Launcher|Apps] browser")
bind(MOD .. " + C", "kitty -e nvim", "[Launcher|Apps] text editor")
bind("CTRL + SHIFT + ESCAPE", "kitty --title btop -e btop", "[Launcher|Apps] system monitor")

bind(MOD .. " + Q", hl.dsp.window.close(), "[Window Management] close focused window")
bind("ALT + F4", hl.dsp.window.close(), "[Window Management] close focused window")
bind(MOD .. " + ALT + F4", hl.dsp.window.kill(), "[Window Management] kill focused window")
bind(MOD .. " + Delete", hl.dsp.exit(), "[Window Management] exit hyprland session")
bind(MOD .. " + W", hl.dsp.window.float({ action = "toggle" }), "[Window Management] toggle float")
bind(MOD .. " + G", hl.dsp.group.toggle(), "[Window Management] toggle group")
bind("ALT + P", hl.dsp.window.pseudo(), "[Window Management] toggle pseudotiling")
bind("SHIFT + F11", cycle_fullscreen, "[Window Management] cycle fullscreen")
bind(MOD .. " + SHIFT + F", hl.dsp.window.pin(), "[Window Management] toggle pin")
bind("CTRL + ALT + DELETE", ipc("logoutToggle"), "[Window Management] logout menu")
bind(MOD .. " + BACKSPACE", ipc("logoutToggle"), "[Window Management] logout menu")
bind(MOD .. " + CTRL + B", ipc("barToggle"), "[Window Management] hide bar")
bind(MOD .. " + L", "torus-lock", "[Window Management] lock session")
bind(MOD .. " + CTRL + H", hl.dsp.group.prev(), "[Window Management|Group Navigation] change active group backwards")
bind(MOD .. " + CTRL + L", hl.dsp.group.next(), "[Window Management|Group Navigation] change active group forwards")
bind(MOD .. " + Left", hl.dsp.focus({ direction = "l" }), "[Window Management|Change focus] focus left")
bind(MOD .. " + Right", hl.dsp.focus({ direction = "r" }), "[Window Management|Change focus] focus right")
bind(MOD .. " + Up", hl.dsp.focus({ direction = "u" }), "[Window Management|Change focus] focus up")
bind(MOD .. " + Down", hl.dsp.focus({ direction = "d" }), "[Window Management|Change focus] focus down")

bind("ALT + TAB", ipc("altTab", "next"), "[Window Management|Alt-tab] cycle next", { transparent = true })
bind("ALT + SHIFT + TAB", ipc("altTab", "prev"), "[Window Management|Alt-tab] cycle previous", { transparent = true })
bind("ALT + ALT_R", ipc("altTab", "apply"), "[Window Management|Alt-tab] switch", { release = true, transparent = true })
bind("ALT + ALT_L", ipc("altTab", "apply"), "[Window Management|Alt-tab] switch", { release = true, transparent = true })

bind(MOD .. " + SHIFT + RIGHT", hl.dsp.window.resize({ x = 30, y = 0, relative = true }), "[Window Management|Resize] right", repeating)
bind(MOD .. " + SHIFT + LEFT", hl.dsp.window.resize({ x = -30, y = 0, relative = true }), "[Window Management|Resize] left", repeating)
bind(MOD .. " + SHIFT + UP", hl.dsp.window.resize({ x = 0, y = -30, relative = true }), "[Window Management|Resize] up", repeating)
bind(MOD .. " + SHIFT + DOWN", hl.dsp.window.resize({ x = 0, y = 30, relative = true }), "[Window Management|Resize] down", repeating)
bind(MOD .. " + SHIFT + CONTROL + LEFT", move_window("l", 30), "[Window Management|Move] left", repeating)
bind(MOD .. " + SHIFT + CONTROL + RIGHT", move_window("r", 30), "[Window Management|Move] right", repeating)
bind(MOD .. " + SHIFT + CONTROL + UP", move_window("u", 30), "[Window Management|Move] up", repeating)
bind(MOD .. " + SHIFT + CONTROL + DOWN", move_window("d", 30), "[Window Management|Move] down", repeating)
bind(MOD .. " + mouse:272", hl.dsp.window.drag(), "[Window Management|Mouse] drag window", { mouse = true })
bind(MOD .. " + mouse:273", hl.dsp.window.resize(), "[Window Management|Mouse] resize window", { mouse = true })
bind(MOD .. " + Z", hl.dsp.window.drag(), "[Window Management|Mouse] hold to move window", { mouse = true })
bind(MOD .. " + X", hl.dsp.window.resize(), "[Window Management|Mouse] hold to resize window", { mouse = true })
bind(MOD .. " + J", hl.dsp.layout("togglesplit"), "[Layout Management|Dwindle] toggle split")

bind(MOD .. " + A", "torus-menu drun", "[Launcher|Menus] application finder")
bind(MOD .. " + TAB", "torus-menu window", "[Launcher|Menus] window switcher")
bind(MOD .. " + SHIFT + E", "torus-menu files", "[Launcher|Menus] file finder")
bind(MOD .. " + slash", ipc("cheatSheetToggle"), "[Launcher|Menus] keybind cheat sheet")
bind(MOD .. " + comma", "torus-menu emoji", "[Launcher|Menus] emoji picker")
bind(MOD .. " + period", "torus-menu glyph", "[Launcher|Menus] glyph picker")
bind(MOD .. " + V", "torus-menu clipboard", "[Launcher|Menus] clipboard")
bind(MOD .. " + SHIFT + V", "torus-menu clipmanager", "[Launcher|Menus] clipboard manager")
bind(MOD .. " + SHIFT + A", "torus-menu style", "[Launcher|Menus] menu style")
bind(MOD .. " + SHIFT + K", "torus-menu calc", "[Launcher|Menus] calculator")
bind(MOD .. " + SHIFT + slash", "torus-menu websearch", "[Launcher|Menus] web search")
bind(MOD .. " + D", ipc("dashboardToggle"), "[Launcher|Shell] dashboard")
bind(MOD .. " + O", ipc("overviewToggle"), "[Launcher|Shell] workspace overview")

bind("F10", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", "[Hardware Controls|Audio] un/mute output", locked)
bind("F11", "wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%-", "[Hardware Controls|Audio] decrease volume", locked_repeat)
bind("F12", "wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+", "[Hardware Controls|Audio] increase volume", locked_repeat)
bind("XF86AudioMute", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", "[Hardware Controls|Audio] un/mute output", locked)
bind("XF86AudioMicMute", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle", "[Hardware Controls|Audio] un/mute microphone", locked)
bind("XF86AudioLowerVolume", "wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%-", "[Hardware Controls|Audio] decrease volume", locked_repeat)
bind("XF86AudioRaiseVolume", "wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+", "[Hardware Controls|Audio] increase volume", locked_repeat)
bind("XF86AudioPlay", "playerctl play-pause", "[Hardware Controls|Media] play media", locked)
bind("XF86AudioPause", "playerctl play-pause", "[Hardware Controls|Media] pause media", locked)
bind("XF86AudioNext", "playerctl next", "[Hardware Controls|Media] next media", locked)
bind("XF86AudioPrev", "playerctl previous", "[Hardware Controls|Media] previous media", locked)
bind(MOD .. " + CTRL + M", "torus-wmute", "[Hardware Controls|Media] un/mute active window")
bind("XF86MonBrightnessUp", "brightnessctl -q set 5%+", "[Hardware Controls|Brightness] increase brightness", locked_repeat)
bind("XF86MonBrightnessDown", "brightnessctl -q set 5%-", "[Hardware Controls|Brightness] decrease brightness", locked_repeat)

bind(MOD .. " + K", "hyprctl switchxkblayout all next", "[Utilities] next keyboard layout", locked)
bind(MOD .. " + ALT + G", "torus-gamemode", "[Utilities] game mode", locked)
bind(MOD .. " + SHIFT + G", "torus-menu games", "[Utilities] game launcher")
bind(MOD .. " + SHIFT + P", "hyprpicker -an", "[Utilities] color picker", locked)
bind(MOD .. " + P", "torus-shot s", "[Utilities] screenshot area", locked)
bind(MOD .. " + CTRL + P", "torus-shot sf", "[Utilities] freeze and screenshot area", locked)
bind(MOD .. " + ALT + P", "torus-shot m", "[Utilities] screenshot monitor", locked)
bind("Print", "torus-shot p", "[Utilities] screenshot all monitors", locked)
bind(MOD .. " + CTRL + S", "torus-shot sc", "[Utilities] OCR to clipboard", locked)
bind(MOD .. " + SHIFT + R", "torus-record toggle", "[Utilities] start or stop recording")
bind(MOD .. " + ALT + R", "torus-record replay-save", "[Utilities] save replay")
bind(MOD .. " + U", "vpnup", "[Utilities] start vpn connection")
bind(MOD .. " + Y", "clipscrub", "[Utilities] censor current clipboard")

bind(MOD .. " + ALT + Right", ipc("wallpaperNext"), "[Theming and Wallpaper] next wallpaper")
bind(MOD .. " + ALT + Left", ipc("wallpaperPrev"), "[Theming and Wallpaper] previous wallpaper")
bind(MOD .. " + ALT + Up", ipc("barPreset", "next"), "[Theming and Wallpaper] next bar preset")
bind(MOD .. " + ALT + Down", ipc("barPreset", "prev"), "[Theming and Wallpaper] previous bar preset")
bind(MOD .. " + SHIFT + W", "torus-menu wallpaper", "[Theming and Wallpaper] select wallpaper")
bind(MOD .. " + SHIFT + T", "torus-menu accent", "[Theming and Wallpaper] select accent color")
bind(MOD .. " + SHIFT + Y", "torus-menu animations", "[Theming and Wallpaper] select animations")
bind(MOD .. " + SHIFT + U", "torus-menu hyprlock", "[Theming and Wallpaper] select lock screen")

local kp = {
	{ "KP_1", "KP_End" },
	{ "KP_2", "KP_Down" },
	{ "KP_3", "KP_Next" },
	{ "KP_4", "KP_Left" },
	{ "KP_5", "KP_Begin" },
	{ "KP_6", "KP_Right" },
	{ "KP_7", "KP_Home" },
	{ "KP_8", "KP_Up" },
	{ "KP_9", "KP_Prior" },
	{ "KP_0", "KP_Insert" },
}
for i = 1, 10 do
	local key = (i == 10) and 0 or i
	bind(MOD .. " + " .. key, hl.dsp.focus({ workspace = i }), "[Workspaces|Navigation] workspace " .. i)
	bind(MOD .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }), "[Workspaces|Move window] to workspace " .. i)
	bind(MOD .. " + ALT + " .. key, hl.dsp.window.move({ workspace = i, follow = false }), "[Workspaces|Move window silently] to workspace " .. i)
	for _, k in ipairs(kp[i]) do
		bind(MOD .. " + " .. k, hl.dsp.focus({ workspace = tostring(i + 10) }), "[Workspaces|Navigation] workspace " .. (i + 10))
		bind(MOD .. " + SHIFT + " .. k, hl.dsp.window.move({ workspace = tostring(i + 10) }), "[Workspaces|Move window] to workspace " .. (i + 10))
	end
end
bind(MOD .. " + CONTROL + RIGHT", hl.dsp.focus({ workspace = "r+1" }), "[Workspaces|Relative] next on this monitor")
bind(MOD .. " + CONTROL + LEFT", hl.dsp.focus({ workspace = "r-1" }), "[Workspaces|Relative] previous on this monitor")
bind(MOD .. " + CONTROL + DOWN", hl.dsp.focus({ workspace = "empty" }), "[Workspaces|Navigation] nearest empty workspace")
bind(MOD .. " + CONTROL + ALT + RIGHT", hl.dsp.window.move({ workspace = "r+1" }), "[Workspaces|Move window] to next workspace")
bind(MOD .. " + CONTROL + ALT + LEFT", hl.dsp.window.move({ workspace = "r-1" }), "[Workspaces|Move window] to previous workspace")
bind(MOD .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), "[Workspaces|Mouse] next workspace")
bind(MOD .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), "[Workspaces|Mouse] previous workspace")
bind(MOD .. " + SHIFT + H", hl.dsp.focus({ workspace = "e-1" }), "[Workspaces|Relative] previous workspace")
bind(MOD .. " + SHIFT + L", hl.dsp.focus({ workspace = "e+1" }), "[Workspaces|Relative] next workspace")
bind(MOD .. " + S", hl.dsp.workspace.toggle_special(), "[Workspaces|Scratchpad] toggle scratchpad")
bind(MOD .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special" }), "[Workspaces|Scratchpad] move window to scratchpad")
bind(MOD .. " + ALT + S", hl.dsp.window.move({ workspace = "special", follow = false }), "[Workspaces|Scratchpad] move window silently to scratchpad")
