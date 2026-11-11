import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs
import "../route.mjs" as R

Provider {
    id: root
    key: "windows"
    name: "Windows"
    glyph: "󰖯"
    help: "open windows; Ctrl+Enter opens the window menu"
    inAll: true
    owning: winFor !== null || ruleFor !== null

    property var items: []
    property var focused: null
    property var ruleFor: null
    property var winFor: null
    property string winBase: ""

    function infoOf(t) {
        const cls = t && t.wayland && t.wayland.appId ? t.wayland.appId : ""
        return cls ? { cls: cls, addr: t.address, title: t.title || cls, ws: t.workspace ? t.workspace.name : "", mon: t.workspace && t.workspace.monitor ? t.workspace.monitor.name : "", floating: !!(t.lastIpcObject && t.lastIpcObject.floating), full: !!(t.lastIpcObject && t.lastIpcObject.fullscreen) } : null
    }

    function rememberFocus() {
        const f = infoOf(Hyprland.activeToplevel)
        if (f)
            focused = f
    }

    function menuFor(f, base) {
        winBase = base
        winFor = f
    }

    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            root.rememberFocus()
        }
    }

    function opened() {
        ruleFor = null
        winFor = null
        const w = []
        for (const t of Hyprland.toplevels.values) {
            const app = t.wayland && t.wayland.appId ? t.wayland.appId : ""
            const top = t
            const e = app ? DesktopEntries.heuristicLookup(app) : null
            w.push({ id: "w", kind: "window", title: t.title || app, sub: app + " · workspace " + (t.workspace ? t.workspace.name : "?"), icon: e ? Quickshell.iconPath(e.icon, true) : "", enter: "focus",
                act: () => Store.focusWindow(top),
                ctrl: { label: "window menu", keep: true, act: () => { const f = root.infoOf(top); if (f) root.menuFor(f, "") } } })
        }
        items = w
        rememberFocus()
        rulesFile.reload()
    }

    function reset() {
        ruleFor = null
    }

    function results(term, scoped) {
        if (ruleFor)
            return ruleResults(ruleFor)
        if (winFor) {
            const rest = term.startsWith(winBase) ? term.slice(winBase.length).trim() : term
            const opts = winResults(winFor)
            return rest === "" ? opts : R.rank(opts, rest, {}, 0).map(x => x.it)
        }
        return items
    }

    function winResults(f) {
        const w = 'window = "address:0x' + f.addr + '"'
        const d = js => () => Hyprland.dispatch(js)
        const opts = []
        for (let n = 1; n <= 9; n++)
            if (String(n) !== f.ws)
                opts.push({ glyph: "󰍹", title: "Move to workspace " + n, keys: "move " + n, act: d("hl.dsp.window.move({ workspace = " + n + ", follow = false, " + w + " })") })
        opts.push(
            { glyph: f.floating ? "󰕴" : "󰉧", title: f.floating ? "Tile it" : "Float it", act: d('hl.dsp.window.float({ action = "toggle", ' + w + " })") },
            { glyph: "󰐃", title: "Pin on every workspace", sub: "floating windows only", hidden: !f.floating || f.full, act: d("hl.dsp.window.pin({ " + w + " })") },
            { glyph: "󰘖", title: "Centre it", hidden: !f.floating || f.full, act: d("hl.dsp.window.center({ " + w + " })") },
            { glyph: "󰊓", title: f.full ? "Leave fullscreen" : "Fullscreen", act: d("hl.dsp.window.fullscreen_state({ internal = " + (f.full ? 0 : 2) + ", client = " + (f.full ? 0 : 2) + ", " + w + " })") },
            { glyph: "󰕮", title: "Rules for " + f.cls, sub: "always float, workspace, monitor…", keep: true, act: () => { root.winFor = null; root.ruleFor = f } },
            { glyph: "󰅖", title: "Close it", act: d("hl.dsp.window.close({ " + w + " })") }
        )
        return opts.filter(o => !o.hidden).map(o => Object.assign({ id: "wa", kind: "action", sub: o.sub || f.title }, o))
    }

    function ruleResults(f) {
        const add = (kind, value) => () => Quickshell.execDetached(["sh", "-c", "out=$(torus-rules \"$@\" 2>&1) || notify-send -a torus 'Window rule not saved' \"$out\"", "sh", "add", f.cls, kind].concat(value ? [value] : []))
        const opts = [
            { glyph: "󰉧", title: "Always float", act: add("float") },
            { glyph: "󰕴", title: "Always tile", act: add("tile") },
            { glyph: "󰍹", title: "Always open on workspace " + f.ws, hidden: !/^[0-9]+$/.test(f.ws), act: add("workspace", f.ws) },
            { glyph: "󰍹", title: "Always open on " + f.mon, hidden: !f.mon, act: add("monitor", f.mon) },
            { glyph: "󰂵", title: "Slightly transparent", act: add("opacity") },
            { glyph: "󰍽", title: "Keep the mouse inside this app", sub: "for games", act: add("cursor") }
        ].filter(o => !o.hidden).map(o => Object.assign({ id: "r", kind: "rule", sub: o.sub || f.cls, enter: "save rule" }, o))
        const mine = rulesFile.text().split("\n").filter(l => l.split("\t")[0] === f.cls)
        if (mine.length > 0)
            opts.push({ id: "r", kind: "rule", glyph: "󰆴", title: "Remove all rules for " + f.cls, sub: mine.map(l => l.split("\t").slice(1).join(" ").trim()).join(", "), enter: "remove", act: () => Quickshell.execDetached(["torus-rules", "remove", f.cls]) })
        return opts
    }

    FileView {
        id: rulesFile
        path: root.stateDir + "/rules.tsv"
        blockLoading: true
        printErrors: false
    }
}
