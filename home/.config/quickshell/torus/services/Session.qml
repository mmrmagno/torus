pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs

Singleton {
    id: root

    property bool on: true
    property real savedAt: 0
    property int saved: 0
    property real restoredAt: 0
    property var skipped: []
    property var windows: []
    readonly property var keep: windows.filter(w => w.verdict === "keep")
    readonly property var lost: windows.filter(w => w.verdict !== "keep")

    function refresh() {
        if (!statusProc.running)
            statusProc.running = true
        if (!previewProc.running)
            previewProc.running = true
    }

    function run(args) {
        actProc.command = ["torus-session"].concat(args)
        actProc.running = true
    }

    function setOn(value) {
        on = value
        run([value ? "on" : "off"])
    }

    function setSkipped(cls, value) {
        run([value ? "skip" : "unskip", cls])
    }

    function saveNow() {
        run(["save"])
    }

    function clear() {
        run(["clear"])
    }

    function ago(t) {
        if (!t)
            return "never"
        const s = Math.max(0, Math.round(Date.now() / 1000 - t))
        if (s < 60)
            return "just now"
        if (s < 3600)
            return Math.round(s / 60) + " min ago"
        if (s < 86400)
            return Math.round(s / 3600) + " h ago"
        return Math.round(s / 86400) + " d ago"
    }

    Process {
        id: statusProc
        command: ["torus-session", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const s = JSON.parse(text)
                    root.on = s.on
                    root.savedAt = s.savedAt
                    root.saved = s.saved
                    root.restoredAt = s.restoredAt
                    root.skipped = s.skipped
                } catch (e) {}
            }
        }
    }

    Process {
        id: previewProc
        command: ["torus-session", "preview"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.windows = JSON.parse(text)
                } catch (e) {}
            }
        }
    }

    Process {
        id: actProc
        onExited: root.refresh()
    }

    Timer {
        interval: 4000
        running: Store.isOpen("session")
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    readonly property real startedAt: Date.now()
    readonly property int windowCount: Hyprland.toplevels.values.length
    onWindowCountChanged: if (Date.now() - startedAt > 90000) autoSave.restart()

    Timer {
        id: autoSave
        interval: 30000
        onTriggered: if (!saveProc.running) saveProc.running = true
    }

    Process {
        id: saveProc
        command: ["torus-session", "save"]
        onExited: if (!statusProc.running) statusProc.running = true
    }

    Component.onCompleted: statusProc.running = true
}
