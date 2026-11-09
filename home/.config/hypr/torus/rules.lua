local function any(list)
	return "^(" .. table.concat(list, "|") .. ")$"
end

hl.window_rule({
	name = "torus_float_class",
	match = {
		class = any({
			"Bitwarden",
			"org\\.keepassxc\\.KeePassXC",
			"hyprland-share-picker",
			"blueman-manager",
			"pavucontrol-qt",
			"com\\.gabm\\.satty",
			"vlc",
			"kvantummanager",
			"qt[56]ct",
			"nwg-(look|displays)",
			"org\\.kde\\.ark",
			"org\\.pulseaudio\\.pavucontrol",
			"nm-(applet|connection-editor)",
			"hyprpolkitagent",
			".*dialog.*",
			"[Xx]dg-desktop-portal-gtk",
			"org\\.freedesktop\\.impl\\.portal\\.desktop\\.(hyprland|gtk)",
			"eog",
			"org\\.gnome\\.eog",
		}),
	},
	float = true,
})

hl.window_rule({
	name = "torus_float_title",
	match = {
		title = any({
			"Progress Dialog — Dolphin",
			"Copying — Dolphin",
			"File Already Exists — Dolphin",
			"Choose Files",
			"Save As.*",
			"Confirm to replace files",
			"File Operation Progress",
			"Open",
			"Open File",
			"Authentication Required",
			"Add Folder to Workspace",
			"File Upload.*",
			"Choose wallpaper.*",
			"Library.*",
			".*dialog.*",
			"Volume Control",
			"Properties for.*",
		}),
	},
	float = true,
})

hl.window_rule({
	name = "torus_pip",
	match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" },
	float = true,
	keep_aspect_ratio = true,
	move = "(monitor_w*0.73) (monitor_h*0.72)",
	size = "(monitor_w*0.25) (monitor_h*0.25)",
	pin = true,
})

hl.window_rule({
	name = "torus_modals",
	match = {
		class = "^(pinentry-.*)$",
		title = any({ "Choose Files", "Open File", "Save As.*", "File Operation Progress", "Authentication Required", "File Upload.*" }),
		modal = true,
	},
	float = true,
	center = true,
	pin = true,
})

hl.window_rule({
	name = "torus_xwaylandvideobridge",
	match = { class = "xwaylandvideobridge" },
	no_initial_focus = true,
	no_focus = true,
	no_anim = true,
	no_blur = true,
	no_follow_mouse = true,
	max_size = { 1, 1 },
	opacity = 0.0,
	float = true,
	workspace = "special:xwayland_video_bridge silent",
})

hl.window_rule({
	name = "torus_filemanagers",
	match = { class = "^(.*dolphin.*)$|^(.*pcmanfm-qt.*)$|^(.*nemo.*)$|.*Nautilus.*" },
	opaque = true,
})

hl.window_rule({
	name = "torus_dropdown",
	match = { class = "^(torus-dropdown)$" },
	float = true,
	size = "(monitor_w*0.75) (monitor_h*0.60)",
	move = "(monitor_w*0.125) (monitor_h*0.08)",
	workspace = "special:term silent",
})

hl.window_rule({
	name = "torus_idle_inhibit_media",
	match = { class = "^(.*celluloid.*|.*mpv.*|.*vlc.*|.*[Ss]potify.*)$" },
	idle_inhibit = "fullscreen",
})

hl.window_rule({
	name = "torus_idle_inhibit_browsers",
	match = { class = "^(.*LibreWolf.*|.*floorp.*|.*brave-browser.*|.*firefox.*|.*chromium.*|.*zen.*|.*vivaldi.*)$" },
	idle_inhibit = "fullscreen",
})

local opacity = {
	{ "0.90 0.90 1", { "firefox", "zen", "brave-browser", "com\\.github\\.rafostar\\.Clapper" } },
	{ "0.80 0.80 1", {
		"code-oss",
		"[Cc]ode",
		"code-url-handler",
		"code-insiders-url-handler",
		"kitty",
		"org\\.kde\\.dolphin",
		"org\\.kde\\.ark",
		"nwg-look",
		"qt5ct",
		"qt6ct",
		"kvantummanager",
		"com\\.github\\.tchx84\\.Flatseal",
		"hu\\.kramo\\.Cartridges",
		"com\\.obsproject\\.Studio",
		"gnome-boxes",
		"vesktop",
		"discord",
		"WebCord",
		"ArmCord",
		"app\\.drey\\.Warp",
		"net\\.davidotek\\.pupgui2",
		"yad",
		"Signal",
		"io\\.github\\.alainm23\\.planify",
		"io\\.gitlab\\.theevilskeleton\\.Upscaler",
		"com\\.github\\.unrud\\.VideoDownloader",
		"io\\.gitlab\\.adhami3310\\.Impression",
		"io\\.missioncenter\\.MissionCenter",
		"io\\.github\\.flattool\\.Warehouse",
	} },
	{ "0.80 0.70 1", {
		"org\\.pulseaudio\\.pavucontrol",
		"blueman-manager",
		"nm-applet",
		"nm-connection-editor",
		"hyprpolkitagent",
		"org\\.freedesktop\\.impl\\.portal\\.desktop\\.(gtk|hyprland)",
	} },
	{ "0.70 0.70 1", { "[Ss]team", "steamwebhelper", "[Ss]potify" } },
	{ "1.00 1.00 1", { "blender" } },
}
for i, rule in ipairs(opacity) do
	hl.window_rule({
		name = "torus_opacity_" .. i,
		match = { class = any(rule[2]) },
		opacity = rule[1],
	})
end

hl.window_rule({
	name = "torus_spotify_title_opacity",
	match = { initial_title = "^(Spotify Free|Spotify Premium)$" },
	opacity = "0.70 0.70 1",
})

hl.window_rule({
	name = "torus_float_misc",
	match = { class = any({ "steam" }), title = any({ "Friends List", "Steam Settings" }) },
	float = true,
})

hl.window_rule({
	name = "torus_float_ghidra",
	match = { class = "^(ghidra.*|.*[Gg]hidra.*)$" },
	float = true,
})

hl.window_rule({
	name = "torus_float_blender_image",
	match = { class = "^(blender)$", title = "^(Blender Render|Blender Image Editor.*)$" },
	float = true,
})

hl.window_rule({
	name = "torus_float_monitors",
	match = { class = "^(kitty)$", title = "^(btop|htop|top)$" },
	float = true,
	size = "(monitor_w*0.6) (monitor_h*0.6)",
	center = true,
})

hl.window_rule({
	name = "torus_jetbrains_popups",
	match = { class = "^(jetbrains-.*)$", title = "^(win[0-9]+)$" },
	no_initial_focus = true,
})

hl.window_rule({
	name = "torus_gamescope",
	match = { class = "^(gamescope|steam_app_[0-9]+)$" },
	idle_inhibit = "fullscreen",
	opacity = "1.00 1.00 1",
})

local layers = any({ "torus-.*", "rofi", "selection" })
hl.layer_rule({ name = "torus_layer_blur", match = { namespace = any({ "torus-bar", "torus-panel", "torus-notifications", "torus-osd", "torus-logout", "rofi" }) }, blur = true })
hl.layer_rule({ name = "torus_layer_ignore_alpha", match = { namespace = layers }, ignore_alpha = 0 })
hl.layer_rule({ name = "torus_layer_no_anim", match = { namespace = any({ "selection", "torus-panel", "torus-logout", "torus-notifications" }) }, no_anim = true })

hl.window_rule({
	name = "torus_games_keep_cursor",
	match = { class = "^(cs2|gamescope|steam_app_[0-9]+)$", fullscreen = true },
	confine_pointer = true,
})
