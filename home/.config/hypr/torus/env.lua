local vars = {
	XDG_CURRENT_DESKTOP = "Hyprland",
	XDG_SESSION_TYPE = "wayland",
	XDG_SESSION_DESKTOP = "Hyprland",
	QT_QPA_PLATFORM = "wayland;xcb",
	QT_QPA_PLATFORMTHEME = "qt6ct",
	QT_AUTO_SCREEN_SCALE_FACTOR = "1",
	QT_WAYLAND_DISABLE_WINDOWDECORATION = "1",
	MOZ_ENABLE_WAYLAND = "1",
	GDK_SCALE = "1",
	ELECTRON_OZONE_PLATFORM_HINT = "auto",
	XCURSOR_SIZE = "24",
	HYPRCURSOR_SIZE = "24",
}
local home = os.getenv("HOME")
local state = (os.getenv("XDG_STATE_HOME") or (home .. "/.local/state")) .. "/torus/"
local probe = io.open("/usr/bin/mangohud", "r")
if probe then
	probe:close()
	vars.MANGOHUD = "1"
	vars.MANGOHUD_CONFIGFILE = state .. "mangohud.conf"
end
for k, v in pairs(vars) do
	hl.env(k, v)
end
