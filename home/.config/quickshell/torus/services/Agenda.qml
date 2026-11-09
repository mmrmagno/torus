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
        if (!fetch.running)
            fetch.running = true
    }

    function parse(text) {
        return text.split("\n").filter(l => l).map(l => {
            const f = l.split("\t")
            return { start: f[0], end: f[1], allDay: f[2] === "1", title: f[3] || "event", place: f[4] || "", at: new Date(f[0]) }
        })
    }

    Process {
        id: fetch
        command: ["torus-calendar", "fetch"]
        onExited: code => {
            root.configured = code !== 3
            file.reload()
        }
    }

    FileView {
        id: file
        path: root.cache
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.events = root.parse(text())
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
                if (mins > 0 && mins <= 10 && !root.warned[key]) {
                    const w = Object.assign({}, root.warned)
                    w[key] = true
                    root.warned = w
                    if (!Store.dnd)
                        Island.flash("notification", { summary: e.title, body: "in " + Math.ceil(mins) + " min" + (e.place ? " · " + e.place : ""), app: "Calendar", icon: "x-office-calendar", image: "" }, 9000)
                }
            }
        }
    }
}
