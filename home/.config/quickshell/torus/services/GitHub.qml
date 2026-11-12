pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    property string status: "idle"
    property string login: ""
    property var mine: []
    property var review: []
    property var failing: []
    property real updated: 0
    readonly property int redCi: mine.filter(p => p.ci === "failure" || p.ci === "error").length
    readonly property int wanted: review.length + failing.length + redCi

    function open(url) {
        Quickshell.execDetached(["torus-launch", "xdg-open", url])
    }

    function refresh() {
        if (!proc.running)
            proc.running = true
    }

    function ago(iso) {
        const m = Math.floor((Date.now() - Date.parse(iso)) / 60000)
        return m < 60 ? Math.max(m, 1) + " min" : m < 1440 ? Math.floor(m / 60) + " h" : Math.floor(m / 1440) + " d"
    }

    Process {
        id: proc
        command: ["torus-gh"]
        stdout: StdioCollector {
            onStreamFinished: {
                let d
                try {
                    d = JSON.parse(text)
                } catch (e) {
                    d = { status: "offline" }
                }
                root.status = d.status || "offline"
                if (d.status !== "ok")
                    return
                root.login = d.login || ""
                root.mine = d.mine || []
                root.review = d.review || []
                root.failing = d.failing || []
                root.updated = Date.now()
            }
        }
    }

    Timer {
        interval: 300000
        repeat: true
        running: !Store.lockSecure && Net.online
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
