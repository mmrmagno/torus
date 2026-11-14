pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    property var jobs: ({})
    property var held: []
    readonly property bool quiet: Fullscreen.any
    readonly property var list: Object.keys(jobs).map(k => jobs[k]).sort((a, b) => a.since - b.since)
    readonly property var visibleJobs: list.filter(j => !(quiet && j.kind === "download"))
    readonly property var top: visibleJobs.length ? visibleJobs[0] : null

    onQuietChanged: if (!quiet && held.length) {
        const h = held
        held = []
        if (h.length === 1)
            Island.flash("notification", h[0], 5000)
        else
            Island.flash("notification", { summary: "Steam finished while you played", body: h.map(n => n.summary).join(" · "), app: "Steam", icon: "steam", image: "", cat: "steam" }, 8000)
    }

    function note(n) {
        if (quiet)
            held = held.concat([n])
        else
            Island.flash("notification", n, 5000)
    }

    function left(s) {
        if (s < 0)
            return ""
        if (s < 60)
            return "under a minute left"
        return Math.round(s / 60) + " min left"
    }

    function handle(ev) {
        const key = ev.kind + ":" + ev.appid
        const j = Object.assign({}, jobs)
        if (ev.state === "running") {
            j[key] = { key: key, kind: ev.kind, appid: ev.appid, name: ev.name, pct: ev.pct, left: ev.left, speed: ev.speed || "", since: (jobs[key] || {}).since || Date.now() }
            jobs = j
            return
        }
        const had = j[key] !== undefined
        delete j[key]
        jobs = j
        if (ev.kind === "shader" && ev.state === "done" && had)
            note({ summary: ev.name + " is ready to play", body: "Vulkan shaders processed", app: "Steam", icon: "steam", image: "", cat: "steam" })
        else if (ev.kind === "download" && ev.state === "done" && had)
            note({ summary: ev.name + " updated", body: "Steam finished the download", app: "Steam", icon: "steam", image: "", cat: "steam" })
    }

    function jobFor(appid, kind) {
        return jobs[kind + ":" + appid] || null
    }

    Process {
        id: follow
        running: true
        command: ["torus-steamlog", "follow"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.handle(JSON.parse(line))
                } catch (e) {}
            }
        }
        onExited: restart.start()
    }

    Timer {
        id: restart
        interval: 30000
        onTriggered: follow.running = true
    }
}
