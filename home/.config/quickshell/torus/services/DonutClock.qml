pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import "../background/donut.mjs" as D

Singleton {
    id: root
    readonly property int w: D.W
    readonly property int h: D.H
    readonly property string chars: D.CHARS
    readonly property real speedA: 1.68
    readonly property real speedB: 0.72
    property int ticks: 0
    readonly property real hour: clock.date.getHours() + clock.date.getMinutes() / 60
    readonly property string art: Store.livingDonut && Island.player && quant.colors.length > 0 ? String(quant.colors[0]).slice(0, 7) : ""
    readonly property var colors: Object.keys(Theme.c).length > 0 ? D.ramp(D.living(Theme.c, hour, art, Store.livingDonut)) : []

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property string artUrl: Store.livingDonut && Island.player ? (Island.player.trackArtUrl || "") : ""
    readonly property string artCache: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/torus/art"
    property string artLocal: ""

    onArtUrlChanged: {
        if (!/^https?:\/\//.test(artUrl)) {
            artLocal = artUrl
            return
        }
        const file = artCache + "/" + Qt.md5(artUrl) + ".img"
        artLocal = ""
        fetch.target = file
        fetch.exec(["sh", "-c", 'mkdir -p "$(dirname "$2")" && find "$(dirname "$2")" -type f -mtime +7 -delete; { [ -s "$2" ] || curl -sfL --max-time 8 -o "$2" -- "$1"; }', "torus-art", artUrl, file])
    }

    Process {
        id: fetch
        property string target: ""
        onExited: code => {
            if (code === 0)
                root.artLocal = "file://" + target
        }
    }

    ColorQuantizer {
        id: quant
        source: root.artLocal
        depth: 1
        rescaleSize: 32
    }
}
