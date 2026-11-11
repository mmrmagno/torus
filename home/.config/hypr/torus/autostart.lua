local start = {
	"uwsm finalize",
	"sh -c 'systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE && systemctl --user restart torus-shell.service; torus-portals'",
	"hypridle",
	"hyprsunset",
	"wl-paste --type text --watch cliphist store",
	"wl-paste --type image --watch cliphist store",
	"wl-clip-persist --clipboard regular",
	"nm-applet --indicator",
	"udiskie --no-automount --smart-tray",
	"blueman-applet",
}

hl.on("hyprland.start", function()
	os.remove(torus.state .. "gamemode")
	for _, cmd in ipairs(start) do
		hl.exec_cmd(cmd)
	end
	hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 24")
	hl.exec_cmd("sh -c 'sleep 8; torus-session restore'")
end)
