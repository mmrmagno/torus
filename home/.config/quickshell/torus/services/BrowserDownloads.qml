pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    property var jobs: ({})
    readonly property var list: Object.keys(jobs).map(k => jobs[k]).sort((a, b) => a.since - b.since)
    readonly property var top: list.length ? list[0] : null
    property string last: ""

    function handle(ev) {
        const j = Object.assign({}, jobs)
        if (ev.state === "running") {
            j[ev.id] = { key: "browser:" + ev.id, kind: "browser", name: ev.name, size: ev.size, speed: ev.speed, pct: -1, left: -1, since: (jobs[ev.id] || {}).since || Date.now() }
        } else {
            delete j[ev.id]
            root.last = ev.state + ":" + ev.name
        }
        jobs = j
    }

    Process {
        id: follow
        running: true
        command: ["torus-downloads", "follow"]
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
