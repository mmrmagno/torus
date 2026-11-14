import test from "node:test"
import assert from "node:assert/strict"
import { caps, label, groups, filter } from "../../home/.config/quickshell/torus/cheatsheet/keys.mjs"

test("keys read like the keyboard", () => {
    assert.deepEqual(caps(64, "grave"), ["Super", "`"])
    assert.deepEqual(caps(65, "slash"), ["Super", "Shift", "/"])
    assert.deepEqual(caps(64, "mouse:272"), ["Super", "left drag"])
    assert.deepEqual(caps(8, "ALT_R"), ["Alt", "release"])
    assert.deepEqual(caps(69, "RIGHT"), ["Super", "Ctrl", "Shift", "→"])
    assert.deepEqual(caps(0, "XF86AudioMicMute"), ["Mic mute"])
    assert.deepEqual(caps(64, "q"), ["Super", "Q"])
    assert.deepEqual(caps(64, "KP_End"), ["Super", "Num End"])
})

test("a bare label gets its sub group", () => {
    assert.deepEqual(label("[Window Management|Resize] right"), { group: "Window Management", what: "resize: right" })
    assert.deepEqual(label("[Window Management|Alt-tab] switch"), { group: "Window Management", what: "alt-tab: switch" })
    assert.deepEqual(label("[Launcher|Apps] browser"), { group: "Launcher", what: "browser" })
    assert.deepEqual(label("[Launcher|Apps] terminal emulator"), { group: "Launcher", what: "terminal emulator" })
    assert.equal(label("no group"), null)
})

test("groups drop numbered workspaces and doubles, search finds raw names too", () => {
    const binds = [
        { modmask: 8, key: "ALT_R", description: "[Window Management|Alt-tab] switch" },
        { modmask: 8, key: "ALT_L", description: "[Window Management|Alt-tab] switch" },
        { modmask: 64, key: "1", description: "[Workspaces|Navigation] workspace 1" },
        { modmask: 64, key: "slash", description: "[Launcher|Menus] keybind cheat sheet" }
    ]
    const g = groups(binds, [{ name: "In panels", items: [] }])
    assert.deepEqual(g.map(x => x.name + ":" + x.items.length), ["Window Management:1", "Launcher:1", "In panels:0"])
    assert.equal(filter(g, "slash").length, 1)
    assert.equal(filter(g, "super /")[0].items[0].what, "keybind cheat sheet")
    assert.equal(filter(g, "nothing here").length, 0)
})
