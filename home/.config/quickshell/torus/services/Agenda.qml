pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    property var events: []
    property bool configured: true
    property var warned: ({})
    readonly property string cache: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/torus/calendar.tsv"

    function onDay(d) {
        const key = Qt.formatDate(d, "yyyy-MM-dd")
        return events.filter(e => e.start.slice(0, 10) <= key && (e.end.slice(0, 10) > key || (e.end.slice(0, 10) === key && e.end.slice(11) !== "00:00") || e.start.slice(0, 10) === key))
    }

    function refresh() {
        if (fetch.running)
            return
        const from = new Date()
        from.setDate(1)
        from.setMonth(from.getMonth() - 1)
        fetch.command = ["torus-calendar", "fetch", "--from", Qt.formatDate(from, "yyyy-MM-dd"), "--days", "150"]
        fetch.running = true
    }

    function parse(text) {
        return text.split("\n").filter(l => l).map(l => {
            const f = l.split("\t")
            return { start: f[0], end: f[1], allDay: f[2] === "1", title: f[3] || "event", place: f[4] || "", link: f[5] || "", at: new Date(f[0]) }
        })
    }

    Process {
        id: fetch
        onExited: code => {
            root.configured = code !== 3
            if (code === 3)
                root.events = []
            else
                file.reload()
        }
    }

    FileView {
        id: file
        path: root.cache
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: if (root.configured) root.events = root.parse(text())
    }

    Timer {
        interval: 900000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        interval: 30000
        running: root.events.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const now = Date.now()
            for (const e of root.events) {
                if (e.allDay)
                    continue
                const mins = (e.at.getTime() - now) / 60000
                const key = e.start + e.title
                if (e.link && mins > 0 && mins <= 2 && !root.warned["join" + key]) {
                    const j = Object.assign({}, root.warned)
                    j["join" + key] = true
                    root.warned = j
                    Quickshell.execDetached(["sh", "-c", "a=$(notify-send -a Calendar -i camera-web -t 150000 -A join=Join \"$1\" \"starts in 2 min, Join opens the call and holds notifications\"); [ \"$a\" = join ] && qs -c torus ipc call torus meetingJoin \"$2\"", "sh", e.title, e.link])
                }
                if (mins > 0 && mins <= 10 && !root.warned[key]) {
                    const w = Object.assign({}, root.warned)
                    w[key] = true
                    root.warned = w
                    if (!Store.dnd)
                        Island.flash("notification", { summary: e.title, body: "in " + Math.ceil(mins) + " min" + (e.place ? " · " + e.place : ""), app: "Calendar", icon: "x-office-calendar", image: "", cat: "meeting" }, 9000)
                }
            }
        }
    }
}
