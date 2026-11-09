pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs

Singleton {
    id: root

    property string query: ""
    signal fill(string text)
    property var counts: ({})
    property var calc: []
    property var files: []
    property var kb: []
    property var apps: []
    property var passItems: []
    property string passState: ""
    property real passLoaded: 0
    property var passPick: null
    property var passFields: null
    readonly property int passClear: Number(Quickshell.env("TORUS_PASS_CLEAR") || 30)
    property var windows: []
    property var focused: null
    property var ruleFor: null
    property var winFor: null
    property string winBase: ""
    readonly property string home: Quickshell.env("HOME")
    readonly property string mode: {
        const c = query.charAt(0)
        if (query.startsWith("p "))
            return "pass"
        if (query.startsWith("n "))
            return "notifs"
        if (query.startsWith("r "))
            return "recent"
        if (query.startsWith("t ") || query === "t")
            return "timer"
        return { "=": "calc", "/": "files", "?": "kb", "!": "ai", ":": "emoji", "#": "colors" }[c] || "all"
    }
    readonly property string term: (mode === "all" ? query : query.slice(mode === "pass" || mode === "notifs" || mode === "recent" || mode === "timer" ? 2 : 1)).trim()
    property var calcHistory: []
    property var recent: []

    readonly property var actions: [
        { id: "a:night", glyph: "󰖔", title: "Night light", sub: NightLight.on ? "on, turn off" : "off, turn on", act: () => NightLight.toggle() },
        { id: "a:nightauto", glyph: "󰖚", title: NightLight.auto ? "Stop the night light schedule" : "Night light at sunset", sub: NightLight.auto ? "on at " + NightLight.sunset + ", off at " + NightLight.sunrise : "on at " + NightLight.sunset + ", off at " + NightLight.sunrise + ", follows your weather location", keys: "night light schedule sunset sunrise auto", act: () => NightLight.setAuto(!NightLight.auto) },
        { id: "a:dnd", glyph: "󰂛", title: "Do not disturb", sub: Store.dnd ? "on, turn off" : "off, turn on", act: () => Store.dnd = !Store.dnd },
        { id: "a:focus25", glyph: "󰔟", title: "Focus 25 minutes", sub: "timer in the island, notifications held", act: () => Focus.start(25) },
        { id: "a:focus50", glyph: "󰔟", title: "Focus 50 minutes", sub: "timer in the island, notifications held", act: () => Focus.start(50) },
        { id: "a:focusstop", glyph: "󰓛", title: "Stop focus", sub: "timer running", hidden: !Focus.running, act: () => Focus.stop() },
        { id: "a:living", glyph: "󰟪", title: "Living donut", sub: Store.livingDonut ? "on, turn off" : "off, turn on", act: () => Store.setLivingDonut(!Store.livingDonut) },
        { id: "a:session", glyph: "󰑓", title: "Session restore", sub: "see what reopens after a reboot", act: () => Store.setOpen("session", true) },
        { id: "a:sessiontoggle", glyph: Session.on ? "󰜺" : "󰑓", title: Session.on ? "Turn session restore off" : "Turn session restore on", sub: Session.on ? "currently on: windows reopen after reboot" : "currently off: nothing reopens after reboot", act: () => Session.setOn(!Session.on) },
        { id: "a:game", glyph: "󰊴", title: "Game mode", sub: "animations, blur and donut off", act: () => Quickshell.execDetached(["torus-gamemode"]) },
        { id: "a:wallnext", glyph: "󰸉", title: "Next wallpaper", sub: "", act: () => Store.stepWallpaper(1) },
        { id: "a:walldonut", glyph: "󰟪", title: "Donut wallpaper", sub: "", act: () => Store.setWallpaper("donut") },
        { id: "a:accent", glyph: "󰏘", title: "Theme", sub: "flavor, accent color, wallpaper, animations", keys: "accent color flavour flavor latte light dark mocha wallpaper animations", act: () => Store.setOpen("theme", true) },
        { id: "a:shot", glyph: "󰹑", title: "Screenshot area", sub: "", act: () => Quickshell.execDetached(["sh", "-c", "sleep 0.3; torus-shot s"]) },
        { id: "a:record", glyph: "󰑋", title: "Record screen", sub: "start or stop", act: () => Quickshell.execDetached(["torus-record", "toggle"]) },
        { id: "a:picker", glyph: "󰈊", title: "Color picker", sub: "pick from the screen, copies hex, # lists past picks", keys: "color color pick eyedropper hex", act: () => Quickshell.execDetached(["sh", "-c", "sleep 0.3; torus-pick"]) },
        { id: "a:clip", glyph: "󰅌", title: "Clipboard history", sub: "", act: () => Store.setOpen("clip", true) },
        { id: "a:dash", glyph: "󰕮", title: "Dashboard", sub: "", act: () => Store.setOpen("dashboard", true) },
        { id: "a:keys", glyph: "󰌌", title: "Keybind cheat sheet", sub: "", act: () => Store.setOpen("cheatsheet", true) },
        { id: "a:lock", glyph: "󰌾", title: "Lock screen", sub: "", act: () => Quickshell.execDetached(["torus-lock"]) },
        { id: "a:timer", glyph: "󰔛", title: "Timer or stopwatch", sub: "type t 5 for five minutes", keys: "timer stopwatch countdown alarm", keep: true, act: () => root.fill("t ") },
        { id: "a:power", glyph: "󰐥", title: "Power menu", sub: "log out, reboot, power off", act: () => Store.setOpen("logout", true) }
    ]

    readonly property var results: {
        const q = term
        let out = []
        if (!Store.isOpen("palette"))
            return out
        if (mode === "all" && ruleFor) {
            return ruleResults(ruleFor)
        }
        if (mode === "all" && winFor) {
            const rest = q.startsWith(winBase) ? q.slice(winBase.length).trim() : q
            const opts = winResults(winFor)
            return rest === "" ? opts : rank(opts, rest)
        }
        if (mode === "all") {
            for (const a of actions)
                if (!a.hidden)
                    out.push(Object.assign({ kind: "action" }, a))
            if (focused)
                out.push({ id: "a:window", kind: "action", keep: true, glyph: "󰖯", title: "Window: " + focused.cls, sub: "move to workspace, float, pin, fullscreen, close, rules…", keys: "window move float tile pin fullscreen close center rule rules", act: () => { root.winBase = root.term; root.winFor = root.focused } })
            out = rank(out.concat(windows, apps), q)
        } else if (mode === "calc") {
            out = q === "" ? calcHistory.map(h => ({ id: "ch", kind: "calc", glyph: "󰋚", title: h.r, sub: h.q + "  ·  enter copies", act: () => Quickshell.execDetached(["wl-copy", "--", h.r.replace(/\u2212/g, "-")]) })) : calc
        } else if (mode === "colors") {
            out = colorsFile.text().split("\n").filter(l => /^#[0-9a-f]{6}$/.test(l) && l.includes(q.toLowerCase().replace("#", ""))).map(h => ({ id: "c:" + h, kind: "color", swatch: h, title: h, sub: "enter copies", act: () => Quickshell.execDetached(["wl-copy", "--", h]) }))
            if (q === "")
                out.unshift({ id: "a:pick2", kind: "action", glyph: "󰈊", title: "Pick a color from the screen", sub: "copies the hex", act: () => Quickshell.execDetached(["sh", "-c", "sleep 0.3; torus-pick"]) })
        } else if (mode === "timer") {
            const t = Timers.parse(q)
            if (Timers.running)
                out.push({ id: "tm:stop", kind: "action", glyph: "󰓛", title: "Stop " + (Timers.stopwatch ? "stopwatch" : "timer") + "  " + Timers.text, sub: Timers.label || "", act: () => Timers.stop() })
            if (t)
                out.push({ id: "tm", kind: "action", glyph: "󰔛", title: "Timer " + (t.secs >= 3600 ? Math.floor(t.secs / 3600) + " h " : "") + (t.secs % 3600 >= 60 ? Math.floor(t.secs % 3600 / 60) + " min " : "") + (t.secs % 60 ? t.secs % 60 + " s" : "") + (t.label ? "  ·  " + t.label : ""), sub: "counts down in the island", act: () => Timers.start(t.secs, t.label) })
            if (q === "") {
                for (const m of [1, 3, 5, 10, 25])
                    out.push({ id: "tm" + m, kind: "action", glyph: "󰔛", title: "Timer " + m + " min", sub: "counts down in the island", act: () => Timers.start(m * 60, "") })
                out.push({ id: "tm:sw", kind: "action", glyph: "󱎫", title: "Stopwatch", sub: "counts up in the island, click pauses", act: () => Timers.startStopwatch() })
            } else if (!t) {
                out.push({ id: "tm:h", kind: "hint", glyph: "󰔛", title: "Try  t 5,  t 90s,  t 1h,  t 10m tea", sub: "minutes by default", act: () => {} })
            }
        } else if (mode === "recent") {
            out = q === "" ? recent : rank(recent, q)
        } else if (mode === "files") {
            out = files
        } else if (mode === "kb") {
            out = kb
        } else if (mode === "ai") {
            out = q === "" ? [] : [{ id: "ai", kind: "ask", glyph: "󰚩", title: "Ask: " + q, sub: "answer in the AI sidebar", act: () => { Store.setOpen("ai", true); Ai.ask(q) } }]
        } else if (mode === "emoji") {
            out = emojiFor(q)
        } else if (mode === "pass") {
            out = passResults(q)
        } else if (mode === "notifs") {
            const words = q.toLowerCase().split(/\s+/).filter(w => w)
            out = Notifs.history.filter(h => words.every(w => (h.app + " " + h.summary + " " + h.body).toLowerCase().includes(w))).slice(0, 40).map(h => ({
                id: "n", kind: "notification", glyph: "󰂚", title: h.summary || h.app, sub: h.app + " · " + Qt.formatTime(new Date(h.time), "hh:mm") + (h.body ? " · " + h.body : ""),
                act: () => Quickshell.execDetached(["wl-copy", "--", h.body || h.summary])
            }))
        }
        return out.slice(0, 40)
    }

    function rememberFocus() {
        const t = Hyprland.activeToplevel
        const cls = t && t.wayland && t.wayland.appId ? t.wayland.appId : ""
        if (cls)
            focused = { cls: cls, addr: t.address, title: t.title || cls, ws: t.workspace ? t.workspace.name : "", mon: t.workspace && t.workspace.monitor ? t.workspace.monitor.name : "", floating: !!(t.lastIpcObject && t.lastIpcObject.floating), full: !!(t.lastIpcObject && t.lastIpcObject.fullscreen) }
    }

    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            root.rememberFocus()
        }
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
            { glyph: "󰍽", title: "Keep the mouse inside when fullscreen", sub: "for games", act: add("cursor") }
        ].filter(o => !o.hidden).map(o => Object.assign({ id: "r", kind: "rule", sub: o.sub || f.cls }, o))
        const mine = rulesFile.text().split("\n").filter(l => l.split("\t")[0] === f.cls)
        if (mine.length > 0)
            opts.push({ id: "r", kind: "rule", glyph: "󰆴", title: "Remove all rules for " + f.cls, sub: mine.map(l => l.split("\t").slice(1).join(" ").trim()).join(", "), act: () => Quickshell.execDetached(["torus-rules", "remove", f.cls]) })
        return opts
    }

    function snapshot() {
        ruleFor = null
        winFor = null
        const w = []
        for (const t of Hyprland.toplevels.values) {
            const app = t.wayland && t.wayland.appId ? t.wayland.appId : ""
            const top = t
            w.push({ id: "w", kind: "window", title: t.title || app, sub: app + " · workspace " + (t.workspace ? t.workspace.name : "?"), icon: iconFor(app), act: () => Store.focusWindow(top) })
        }
        rememberFocus()
        rulesFile.reload()
        const a = []
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay)
                continue
            const entry = e
            a.push({ id: "app:" + e.id, kind: "app", title: e.name, sub: e.genericName || e.comment || "", keys: (e.keywords || []).join(" "), icon: Quickshell.iconPath(e.icon, true), act: () => entry.execute() })
        }
        windows = w
        apps = a
    }

    function passResults(q) {
        if (passPick) {
            const it = passPick
            if (passFields === null)
                return [{ id: "ph", kind: "hint", glyph: "󰔟", title: "Checking " + it.title + "…", sub: "looking up which fields it has", act: () => {} }]
            const open = { id: "po", kind: "app", glyph: "󰟵", title: "Open Proton Pass", sub: "for anything else in this item", act: () => Quickshell.execDetached(["proton-pass"]) }
            if (passFields.length === 0)
                return [{ id: "pn", kind: "field", glyph: "󰈚", title: "Name", sub: it.title + " · copy", act: () => Quickshell.execDetached(["wl-copy", "--", it.title]) }, open]
            const labels = [["password", "󰌾", "Password"], ["email", "󰇮", "Email"], ["username", "󰀄", "Username"], ["totp", "󰔟", "One-time code"],
                ["urls", "󰖟", "Website"], ["number", "󰆛", "Card number"], ["cvv", "󰆛", "CVV"], ["cardholder_name", "󰀄", "Cardholder"],
                ["expiration_date", "󰃭", "Expiry"], ["private_key", "󰌆", "Private key"], ["public_key", "󰌆", "Public key"], ["note", "󰎚", "Note"]]
            const name = { id: "pn", kind: "field", glyph: "󰈚", title: "Name", sub: it.title + " · copy", act: () => Quickshell.execDetached(["wl-copy", "--", it.title]) }
            return labels.filter(f => passFields.indexOf(f[0]) >= 0).map(f => ({
                id: "pf", kind: "field", glyph: f[1], title: f[2], sub: it.title + " · copy, clears in " + passClear + " s",
                act: () => copyField(it, f[0])
            })).concat([name, open])
        }
        if (passState === "error")
            return [{ id: "ph", kind: "hint", glyph: "󰟵", title: "Proton Pass is locked", sub: "run pass-cli login in a terminal, then try again", act: () => {} }]
        if (passItems.length === 0)
            return [{ id: "ph", kind: "hint", glyph: "󰟵", title: "Loading your vaults…", sub: "names only, nothing is shown or saved", act: () => {} }]
        const items = passItems.map(p => ({ id: "p", kind: "pass", keep: true, glyph: "󰟵", title: p.title, sub: p.vault, sid: p.sid, iid: p.iid, act: null }))
        for (const it of items)
            it.act = () => root.openPassItem(it)
        return q === "" ? items : rank(items, q)
    }

    function openPassItem(it) {
        passFields = null
        passPick = it
        fieldsProc.asked = it.iid
        fieldsProc.exec(["torus-pass", "fields", it.sid, it.iid])
    }

    function loadPass() {
        if (passProc.running || (passState === "ready" && Date.now() - passLoaded < 300000))
            return
        passState = "loading"
        passProc.running = true
    }

    function copyField(item, field) {
        Quickshell.execDetached(["torus-pass", "copy", item.sid, item.iid, field, String(passClear)])
    }

    function iconFor(app) {
        const e = app ? DesktopEntries.heuristicLookup(app) : null
        return e ? Quickshell.iconPath(e.icon, true) : ""
    }

    function score(q, s) {
        if (!s)
            return 0
        const t = s.toLowerCase()
        if (t.startsWith(q))
            return 100
        const i = t.indexOf(q)
        if (i > 0)
            return /[\s\-_.]/.test(t.charAt(i - 1)) ? 70 : 40
        let j = 0
        for (let k = 0; k < t.length && j < q.length; k++)
            if (t.charAt(k) === q.charAt(j))
                j++
        return j === q.length ? 10 : 0
    }

    function rank(items, q) {
        const ql = q.toLowerCase()
        const scored = []
        for (const it of items) {
            const base = ql === "" ? 1 : Math.max(score(ql, it.title), score(ql, it.sub) * 0.5, score(ql, it.keys) * 0.6)
            if (base <= 0)
                continue
            const boost = Math.min(30, (counts[it.id] || 0) * 5)
            const kind = it.kind === "window" ? 3 : (it.kind === "app" ? 2 : 1)
            scored.push({ it: it, s: base + boost + kind })
        }
        scored.sort((a, b) => b.s - a.s || a.it.title.localeCompare(b.it.title))
        return scored.map(x => x.it)
    }

    function emojiFor(q) {
        const words = q.toLowerCase().split(/\s+/).filter(w => w)
        const out = []
        for (const line of emojiFile.text().split("\n")) {
            if (!line || !words.every(w => line.toLowerCase().includes(w)))
                continue
            const ch = line.split(" ")[0]
            out.push({ id: "e:" + ch, kind: "emoji", glyph: ch, title: line.slice(ch.length + 1).split(/\s+/).slice(0, 4).join(" "), sub: "copy", act: () => Quickshell.execDetached(["wl-copy", "--", ch]) })
            if (out.length >= 40)
                break
        }
        return out
    }

    function run(item) {
        if (!item)
            return
        if (item.keep) {
            item.act()
            return
        }
        if (item.kind === "app" || item.kind === "action") {
            const c = Object.assign({}, counts)
            c[item.id] = Math.min(50, (c[item.id] || 0) + 1)
            counts = c
            countsFile.setText(JSON.stringify(c))
        }
        Store.setOpen("palette", false)
        item.act()
    }

    onModeChanged: {
        if (mode === "pass")
            loadPass()
        else if (mode === "colors")
            colorsFile.reload()
        else if (mode === "recent" && !recentProc.running)
            recentProc.running = true
    }
    onTermChanged: {
        ruleFor = null
        passPick = null
        passFields = null
        calc = []
        files = []
        kb = []
        debounce.restart()
    }
    Timer {
        id: debounce
        interval: 120
        onTriggered: {
            if (root.term.length === 0)
                return
            const t = root.term
            if (root.mode === "calc") {
                calcProc.asked = t
                calcProc.exec(["qalc", "-t", "--", t])
            } else if (root.mode === "files" && t.length >= 2) {
                filesProc.asked = t
                filesProc.exec(["fd", "-F", "--type", "f", "--max-results", "40", "--color", "never", "--", t, root.home])
            } else if (root.mode === "kb" && t.length >= 2) {
                kbProc.asked = t
                kbProc.exec(["rg", "-i", "-F", "-n", "--max-count", "1", "--max-columns", "160", "--glob", "*.md", "--", t, root.home + "/dev/kb"])
            }
        }
    }

    Process {
        id: calcProc
        property string asked: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (calcProc.asked !== root.term || root.mode !== "calc")
                    return
                const r = text.trim()
                const plain = r.replace(/\u2212/g, "-")
                const asked = calcProc.asked
                root.calc = r === "" ? [] : [{ id: "calc", kind: "calc", glyph: "󰃬", title: r, sub: "enter copies", act: () => {
                    root.calcHistory = [{ q: asked, r: r }].concat(root.calcHistory.filter(h => h.q !== asked)).slice(0, 15)
                    Quickshell.execDetached(["wl-copy", "--", plain])
                } }]
            }
        }
    }

    Process {
        id: filesProc
        property string asked: ""
        stdout: StdioCollector {
            onStreamFinished: if (filesProc.asked === root.term && root.mode === "files") root.files = text.split("\n").filter(l => l).slice(0, 40).map(p => ({
                id: "f:" + p, kind: "file", glyph: "󰈔", title: p.split("/").pop(), sub: p.replace(root.home, "~"),
                act: () => Quickshell.execDetached(["xdg-open", p])
            }))
        }
    }

    Process {
        id: kbProc
        property string asked: ""
        stdout: StdioCollector {
            onStreamFinished: if (kbProc.asked === root.term && root.mode === "kb") root.kb = text.split("\n").filter(l => l).slice(0, 40).map(l => {
                const m = l.match(/^(.*?):(\d+):(.*)$/)
                if (!m)
                    return null
                const rel = m[1].replace(root.home + "/dev/kb/", "")
                return { id: "kb:" + rel, kind: "kb", glyph: "󰈙", title: m[3].trim() || rel, sub: rel + ":" + m[2], act: () => Quickshell.execDetached(["kitty", "-e", "nvim", "+" + m[2], m[1]]) }
            }).filter(x => x)
        }
    }

    Process {
        id: fieldsProc
        property string asked: ""
        stdout: StdioCollector {
            onStreamFinished: if (root.passPick && root.passPick.iid === fieldsProc.asked) root.passFields = text.split("\n").filter(l => l)
        }
    }

    Process {
        id: passProc
        command: ["torus-pass", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const items = text.split("\n").filter(l => l).map(l => {
                    const f = l.split("\t")
                    return { sid: f[0], iid: f[1], vault: f[2], title: f[3] }
                }).filter(p => p.title)
                root.passItems = items
                root.passState = items.length > 0 ? "ready" : "error"
                root.passLoaded = Date.now()
            }
        }
    }

    FileView {
        id: rulesFile
        path: (Quickshell.env("XDG_STATE_HOME") || root.home + "/.local/state") + "/torus/rules.tsv"
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: emojiFile
        path: root.home + "/.local/share/torus/emoji.db"
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: countsFile
        path: (Quickshell.env("XDG_STATE_HOME") || root.home + "/.local/state") + "/torus/palette.json"
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                root.counts = JSON.parse(text())
            } catch (e) {
                root.counts = {}
            }
        }
    }

    FileView {
        id: colorsFile
        path: (Quickshell.env("XDG_STATE_HOME") || root.home + "/.local/state") + "/torus/colors"
        printErrors: false
    }

    Process {
        id: recentProc
        command: ["torus-recent", "40"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {}
                root.recent = text.split("\n").filter(l => l).map(l => {
                    const path = l.split("\t")[1] || ""
                    if (!path || seen[path])
                        return null
                    seen[path] = true
                    return { id: "rf:" + path, kind: "file", glyph: "󰈔", title: path.split("/").pop(), sub: path.replace(root.home, "~") + "  ·  " + l.slice(0, 10), act: () => Quickshell.execDetached(["xdg-open", path]) }
                }).filter(x => x).slice(0, 40)
            }
        }
    }
}
