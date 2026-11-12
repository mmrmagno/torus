pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.palette.providers
import "../palette/route.mjs" as R

Singleton {
    id: root

    property string query: ""
    property string tabScope: "all"
    signal fill(string text)
    property var frec: ({})
    readonly property string home: Quickshell.env("HOME")
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/torus"

    readonly property var providers: [appsP, windowsP, actionsP, projectsP, recentP, sshP, githubP, containersP, displaysP, calcP, filesP, webP, colorsP, emojiP, timerP, notifsP, otpP, kbP, aiP, passP]
    readonly property var win: windowsP
    readonly property var prefixed: providers.filter(p => p.prefix !== "").sort((a, b) => b.prefix.length - a.prefix.length)
    readonly property var parsed: R.parse(query, prefixed, tabScope)
    readonly property string mode: parsed.scope
    readonly property string term: parsed.term
    readonly property var current: byKey(mode)

    function byKey(k) {
        for (const p of providers)
            if (p.key === k)
                return p
        return null
    }

    readonly property var results: {
        if (!Store.isOpen("palette"))
            return []
        const now = Date.now()
        for (const p of providers)
            if (p.owning && (mode === "all" || mode === p.key))
                return p.results(term, true).slice(0, 40)
        if (mode !== "all") {
            const p = current
            if (!p)
                return []
            const r = p.results(term, true)
            return (p.ranked ? r : R.rank(r, term, frec, now).map(x => x.it)).slice(0, 40)
        }
        if (term === "")
            return emptyState(now)
        const d = R.detect(term)
        let top = []
        for (const p of providers)
            if (p.smart && !p.secret && p.wants(term, d))
                top = top.concat(p.results(term, false).map(it => Object.assign({}, it, { section: p.section })))
        const groups = []
        for (const p of providers)
            if (p.inAll && !p.secret)
                groups.push({ section: p.section, rows: R.rank(p.results(term, false), term, frec, now) })
        return top.concat(R.arrange(groups, 4)).slice(0, 40)
    }

    readonly property var scopeOrder: ["all", "apps", "files", "projects", "pass", "ssh", "github", "containers", "windows", "actions", "recent", "calc", "colors", "emoji", "timer", "notifs", "kb", "ai"]
    readonly property var scopes: scopeOrder.map(k => k === "all" ? { key: "all", name: "All", glyph: "󰍉", prefix: "" } : byKey(k)).filter(p => p && (p.key === "all" || p.scoped)).map(p => ({ key: p.key, name: p.name, glyph: p.glyph, prefix: p.prefix }))
    readonly property string glyph: current ? current.glyph : "󰍉"
    readonly property bool help: mode === "kb" && term === ""

    function emptyState(now) {
        let pool = []
        for (const p of providers)
            if (p.inAll && !p.secret && p.key !== "windows" && p.key !== "recent")
                pool = pool.concat(p.results("", false))
        const tag = (list, section) => list.map(it => Object.assign({}, it, { section: section }))
        return tag(R.frecent(pool, frec, now, 6), "Frequent").concat(tag(windowsP.results("", false).slice(0, 4), "Windows"))
    }

    function cycleScope(dir) {
        const keys = scopes.map(s => s.key)
        const i = Math.max(0, keys.indexOf(mode))
        setScope(keys[(i + dir + keys.length) % keys.length])
    }

    function helpRows() {
        return scopes.filter(s => s.key !== "all").map(s => byKey(s.key)).map(p => ({
            id: "help:" + p.key, kind: "help", section: "Scopes, Enter jumps there", chip: p.prefix.trim() || "Tab", glyph: p.glyph, title: p.name, sub: p.help, keep: true, enter: "go there",
            act: () => root.setScope(p.key)
        }))
    }

    function put(text) {
        query = text
        fill(text)
    }

    function setScope(key) {
        const p = key === "all" ? null : byKey(key)
        const t = term
        if (p && p.prefix !== "") {
            tabScope = "all"
            put(p.prefix + t)
        } else {
            tabScope = key
            put(t)
        }
    }

    function enterLabel(item) {
        return item.enter || ({ app: "launch", window: "focus", action: "run", calc: "copy", file: "open", folder: "open", emoji: "copy", color: "copy", notification: "copy" })[item.kind] || (item.kind === "hint" ? "" : "select")
    }

    function remembered(item) {
        return !item.keep && ["app", "action", "project", "ssh"].indexOf(item.kind) >= 0 && String(item.id).indexOf(":") > 0
    }

    function run(item, how) {
        if (!item)
            return
        const a = how === "ctrl" ? item.ctrl : (how === "alt" ? item.alt : (how === "layout" ? item.layout : item))
        if (!a || !a.act)
            return
        if (a.keep) {
            a.act()
            return
        }
        if (remembered(item)) {
            frec = R.bump(frec, item.id, Date.now())
            frecFile.setText(JSON.stringify(frec))
        }
        Store.setOpen("palette", false)
        a.act()
    }

    function snapshot() {
        tabScope = "all"
        for (const p of providers)
            if (p.opened)
                p.opened()
    }

    onModeChanged: {
        const p = byKey(mode)
        if (p && p.entered)
            p.entered()
    }
    onTermChanged: {
        for (const p of providers)
            if (p.reset)
                p.reset()
        debounce.restart()
    }

    Timer {
        id: debounce
        interval: 120
        onTriggered: {
            if (root.term.length === 0)
                return
            if (root.mode === "all") {
                const d = R.detect(root.term)
                for (const p of root.providers)
                    if (p.smart && !p.secret && p.settle && p.wants(root.term, d))
                        p.settle(root.term)
            } else {
                const p = root.byKey(root.mode)
                if (p && p.settle)
                    p.settle(root.term)
            }
        }
    }

    AppsProvider { id: appsP }
    WindowsProvider { id: windowsP }
    ActionsProvider { id: actionsP }
    ProjectsProvider { id: projectsP }
    SshProvider { id: sshP }
    GithubProvider { id: githubP }
    ContainersProvider { id: containersP }
    DisplaysProvider { id: displaysP }
    RecentProvider { id: recentP }
    CalcProvider { id: calcP }
    FilesProvider { id: filesP }
    WebProvider { id: webP }
    ColorsProvider { id: colorsP }
    EmojiProvider { id: emojiP }
    TimerProvider { id: timerP }
    NotifsProvider { id: notifsP }
    OtpProvider { id: otpP }
    KbProvider { id: kbP }
    AiProvider { id: aiP }
    PassProvider { id: passP }

    FileView {
        id: frecFile
        path: root.stateDir + "/palette-frecency.json"
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                root.frec = JSON.parse(text())
            } catch (e) {
                root.frec = {}
            }
        }
        onLoadFailed: oldCounts.reload()
    }

    FileView {
        id: oldCounts
        path: root.stateDir + "/palette.json"
        preload: false
        printErrors: false
        onLoaded: {
            try {
                root.frec = R.fromCounts(JSON.parse(text()), Date.now())
                frecFile.setText(JSON.stringify(root.frec))
            } catch (e) {
                root.frec = {}
            }
        }
    }
}
