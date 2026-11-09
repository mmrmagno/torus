pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    property bool running: false
    property bool paused: false
    property bool stopwatch: false
    property string label: ""
    property int total: 0
    property real startedAt: 0
    property real pausedFor: 0
    property real pausedAt: 0
    property int elapsed: 0
    readonly property int left: Math.max(0, total - elapsed)
    readonly property real progress: stopwatch ? (elapsed % 60) / 60 : (total > 0 ? elapsed / total : 0)
    readonly property string text: {
        const s = stopwatch ? elapsed : left
        const h = Math.floor(s / 3600)
        const mm = String(Math.floor(s % 3600 / 60)).padStart(2, "0")
        const ss = String(s % 60).padStart(2, "0")
        return (h > 0 ? h + ":" : "") + mm + ":" + ss
    }

    function parse(spec) {
        const m = /^(\d+(?:[.,]\d+)?)\s*(s|sec|m|min|h|hr)?\b\s*(.*)$/i.exec(spec.trim())
        if (!m)
            return null
        const n = parseFloat(m[1].replace(",", "."))
        const unit = (m[2] || "m").toLowerCase()
        const secs = Math.round(n * (unit.startsWith("h") ? 3600 : unit.startsWith("s") ? 1 : 60))
        return secs > 0 && secs <= 86400 ? { secs: secs, label: m[3].trim() } : null
    }

    function start(secs, name) {
        stopwatch = false
        total = secs
        label = name || ""
        begin()
    }

    function startStopwatch() {
        stopwatch = true
        total = 0
        label = ""
        begin()
    }

    function begin() {
        startedAt = Date.now()
        pausedFor = 0
        paused = false
        elapsed = 0
        running = true
    }

    function togglePause() {
        if (!running)
            return
        if (paused) {
            pausedFor += Date.now() - pausedAt
            paused = false
        } else {
            pausedAt = Date.now()
            paused = true
        }
    }

    function stop() {
        running = false
        paused = false
    }

    Timer {
        interval: 250
        repeat: true
        running: root.running && !root.paused
        onTriggered: {
            root.elapsed = Math.floor((Date.now() - root.startedAt - root.pausedFor) / 1000)
            if (!root.stopwatch && root.elapsed >= root.total) {
                const what = root.label
                root.stop()
                Quickshell.execDetached(["sh", "-c", "pw-play /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null || pw-play /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null || true"])
                Quickshell.execDetached(["notify-send", "-a", "Timer", "-i", "alarm-symbolic", what ? "Timer done: " + what : "Timer done", "time is up"])
            }
        }
    }
}
