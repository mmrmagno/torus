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
for k, v in pairs(vars) do
	hl.env(k, v)
end
