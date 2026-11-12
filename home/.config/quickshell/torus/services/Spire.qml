pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    property var data: ({ ok: false, reason: "not checked yet" })
    property var amt: []
    property bool hasContext: true
    property real updated: 0
    readonly property bool ok: data.ok === true
    readonly property int problems: ok ? (data.problems || 0) : 0
    readonly property bool hubOpen: Store.isOpen("homelab")
    readonly property bool allowed: !Store.locked && !Store.lockSecure && Net.online && hasContext

    function refresh() {
        if (!status.running)
            status.running = true
        if (hubOpen && !amtProc.running)
            amtProc.running = true
    }

    function open(url) {
        Quickshell.execDetached(["xdg-open", url])
    }

    function ago(iso) {
        if (!iso)
            return "never"
        const m = Math.floor((Date.now() - Date.parse(iso)) / 60000)
        return m < 60 ? Math.max(m, 1) + " min ago" : m < 1440 ? Math.floor(m / 60) + " h ago" : Math.floor(m / 1440) + " d ago"
    }

    onHubOpenChanged: if (hubOpen) refresh()

    Process {
        id: status
        command: ["torus-spire", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                let d
                try {
                    d = JSON.parse(text)
                } catch (e) {
                    d = { ok: false, reason: "torus-spire failed" }
                }
                root.hasContext = d.reason !== "no kubectl context"
                root.data = d
                root.updated = Date.now()
            }
        }
    }

    Process {
        id: amtProc
        command: ["torus-spire", "amt-check"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.amt = JSON.parse(text)
                } catch (e) {
                    root.amt = []
                }
            }
        }
    }

    Timer {
        interval: root.hubOpen ? 60000 : 600000
        repeat: true
        running: root.allowed
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
