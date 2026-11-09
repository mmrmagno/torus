pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    property bool on: false
    property int temperature: 6000
    property int seen: -1
    readonly property int warm: 5500
    property bool auto: false
    property string phase: ""
    property var ramp: []
    readonly property string sunset: Weather.sunset || "19:00"
    readonly property string sunrise: Weather.sunrise || "07:00"

    function setAuto(value) {
        auto = value
        autoFile.setText(value ? "on\n" : "off\n")
        phase = ""
        if (value)
            tick()
    }

    function minutes(hhmm) {
        const p = hhmm.split(":")
        return parseInt(p[0]) * 60 + parseInt(p[1])
    }

    function nightNow() {
        const d = new Date()
        const now = d.getHours() * 60 + d.getMinutes()
        const a = minutes(sunset)
        const b = minutes(sunrise)
        return a > b ? (now >= a || now < b) : (now >= a && now < b)
    }

    function tick() {
        if (!auto)
            return
        const p = nightNow() ? "night" : "day"
        if (p === phase)
            return
        const first = phase === ""
        phase = p
        if ((p === "night") !== on)
            fade(p === "night", first)
    }

    function fade(toWarm, quick) {
        on = toWarm
        const steps = []
        const n = quick ? 1 : 20
        for (let i = 1; i <= n; i++)
            steps.push(Math.round(toWarm ? 6500 - (6500 - warm) * i / n : warm + (6500 - warm) * i / n))
        ramp = steps
        rampTimer.restart()
    }

    function refresh() {
        if (!query.running)
            query.running = true
    }

    function toggle() {
        rampTimer.stop()
        ramp = []
        const next = !root.on
        root.on = next
        Quickshell.execDetached(["hyprctl", "hyprsunset", next ? "temperature " + root.warm : "identity"])
        if (next) {
            root.temperature = root.warm
            root.seen = root.warm
        }
        settle.restart()
    }

    Process {
        id: query
        command: ["hyprctl", "hyprsunset", "temperature"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(text)
                if (n > 0 && n !== root.seen) {
                    root.seen = n
                    root.temperature = n
                    root.on = n < 6000
                }
            }
        }
    }

    Timer {
        id: rampTimer
        interval: 1500
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (root.ramp.length === 0) {
                stop()
                settle.restart()
                return
            }
            const t = root.ramp[0]
            root.ramp = root.ramp.slice(1)
            const last = root.ramp.length === 0
            Quickshell.execDetached(["hyprctl", "hyprsunset", last && !root.on ? "identity" : "temperature " + t])
            root.temperature = t
            root.seen = t
        }
    }

    Timer {
        interval: 60000
        running: root.auto
        repeat: true
        onTriggered: root.tick()
    }

    FileView {
        id: autoFile
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/torus/night-auto"
        blockLoading: true
        printErrors: false
        onLoaded: {
            root.auto = text().trim() === "on"
            root.tick()
        }
    }

    Connections {
        target: Weather
        function onSunsetChanged() {
            root.tick()
        }
    }

    Timer {
        id: settle
        interval: 400
        onTriggered: root.refresh()
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
