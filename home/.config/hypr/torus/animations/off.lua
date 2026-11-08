for _, leaf in ipairs({ "global", "windows", "windowsIn", "windowsOut", "windowsMove", "layers", "layersIn", "layersOut", "fade", "fadeIn", "fadeOut", "fadeSwitch", "fadeShadow", "fadeGlow", "fadeDim", "border", "borderangle", "workspaces", "specialWorkspace" }) do
	hl.animation({ leaf = leaf, enabled = false })
end
