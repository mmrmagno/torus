hl.curve("emphasized", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })
hl.curve("emphasizedAccel", { type = "bezier", points = { { 0.3, 0 }, { 0.8, 0.15 } } })
hl.curve("menuDecel", { type = "bezier", points = { { 0.1, 1 }, { 0, 1 } } })
hl.curve("menuAccel", { type = "bezier", points = { { 0.38, 0.04 }, { 1, 0.07 } } })
hl.curve("spin", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })
hl.curve("bouncy", { type = "spring", mass = 1, stiffness = 170, damping = 22 })
hl.curve("soft", { type = "spring", mass = 1, stiffness = 120, damping = 20 })
hl.animation({ leaf = "windows", enabled = true, speed = 4, spring = "bouncy", style = "popin 80%" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4, spring = "bouncy", style = "popin 80%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "emphasizedAccel", style = "popin 80%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, spring = "soft", style = "slide" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 60, bezier = "spin", style = "loop" })
hl.animation({ leaf = "fade", enabled = true, speed = 4, bezier = "emphasized" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 3, spring = "soft", style = "slide" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2, bezier = "menuAccel", style = "slide" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 2, bezier = "menuDecel" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 3, bezier = "menuAccel" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, spring = "soft", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, spring = "bouncy", style = "slidevert" })
hl.config({
	decoration = {
		wobble = { enabled = true, intensity = 0.12, stiffness = 220, damping = 14, mesh = 12 },
		motion_blur = { enabled = true, samples = 9 },
		glow = { enabled = true, range = 14, render_power = 3 },
		blur = { variant = 1 },
	},
	misc = { animate_manual_resizes = true },
})
