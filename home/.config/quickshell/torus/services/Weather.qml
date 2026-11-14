pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    property bool ok: false
    property bool tried: false
    readonly property bool busy: proc.running
    property string temp: "--"
    property string feels: "--"
    property string desc: "weather unavailable"
    property string icon: "󰖐"
    property string place: ""
    property var hours: []
    property string sunrise: ""
    property string sunset: ""

    function clock24(t) {
        const m = /^(\d+):(\d+)\s*(AM|PM)$/i.exec((t || "").trim())
        if (!m)
            return ""
        let h = parseInt(m[1]) % 12
        if (m[3].toUpperCase() === "PM")
            h += 12
        return (h < 10 ? "0" : "") + h + ":" + m[2]
    }

    function iconFor(code) {
        const c = parseInt(code)
        if (c === 113) return "󰖙"
        if (c === 116) return "󰖕"
        if (c === 119 || c === 122) return "󰖐"
        if ([143, 248, 260].includes(c)) return "󰖑"
        if (c >= 386) return "󰖓"
        if ([179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371].includes(c)) return "󰖘"
        return "󰖗"
    }

    function checkRain() {
        if (!rain.running)
            rain.running = true
    }

    function refresh() {
        proc.running = true
    }

    Process {
        id: proc
        command: ["curl", "-sf", "--max-time", "10", "https://wttr.in/?format=j1"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text)
                    const cur = j.current_condition[0]
                    root.temp = cur.temp_C + "°"
                    root.feels = cur.FeelsLikeC + "°"
                    root.desc = cur.weatherDesc[0].value
                    root.icon = root.iconFor(cur.weatherCode)
                    root.place = j.nearest_area ? j.nearest_area[0].areaName[0].value : ""
                    root.hours = j.weather[0].hourly.filter((h, i) => i % 2 === 0).map(h => ({ t: (parseInt(h.time) / 100) + ":00", temp: h.tempC + "°", icon: root.iconFor(h.weatherCode) }))
                    const astro = j.weather[0].astronomy ? j.weather[0].astronomy[0] : null
                    root.sunrise = astro ? root.clock24(astro.sunrise) : ""
                    root.sunset = astro ? root.clock24(astro.sunset) : ""
                    root.ok = true
                } catch (e) {
                    root.ok = false
                    root.desc = "weather unavailable"
                }
            }
        }
        onExited: code => {
            root.tried = true
            if (code !== 0) {
                root.ok = false
                root.desc = "weather unavailable"
            }
        }
    }

    Timer {
        interval: 1800000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: rain
        command: ["torus-rain"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)
                    if (d.due)
                        Quickshell.execDetached(["notify-send", "-a", "Weather", "-i", "weather-showers", d.title, d.body])
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 600000
        running: Net.online && !Store.lockSecure
        repeat: true
        triggeredOnStart: true
        onTriggered: root.checkRain()
    }
}
