pragma Singleton
import QtQuick
import Quickshell
import qs
import "../background/donut.mjs" as D

Singleton {
    id: root

    readonly property int w: D.W
    readonly property int h: D.H
    readonly property string chars: D.CHARS
    property int index: 0
    property real phase: 0
    property string url: encode(D.grid(1, 1))
    property int ticks: 0
    property int consumers: 0
    property var cache: []
    readonly property var colors: Object.keys(Theme.c).length > 0 ? D.ramp(Theme.c) : []
    readonly property bool running: consumers > 0 && !Store.gamemode

    function encode(g) {
        const px = []
        for (let i = 0; i < g.length; i++)
            px.push(g[i] < 0 ? 0 : (g[i] + 1) * 16)
        const text = "P2\n" + D.W + " " + D.H + "\n255\n" + px.join(" ") + "\n"
        return "data:image/x-portable-graymap;base64," + base64(text)
    }

    function base64(text) {
        const abc = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        let out = ""
        for (let i = 0; i < text.length; i += 3) {
            const a = text.charCodeAt(i)
            const b = i + 1 < text.length ? text.charCodeAt(i + 1) : 0
            const c = i + 2 < text.length ? text.charCodeAt(i + 2) : 0
            const n = (a << 16) | (b << 8) | c
            out += abc[(n >> 18) & 63] + abc[(n >> 12) & 63]
            out += i + 1 < text.length ? abc[(n >> 6) & 63] : "="
            out += i + 2 < text.length ? abc[n & 63] : "="
        }
        return out
    }

    function frame(i) {
        let f = cache[i]
        if (!f) {
            const a = D.loopAngles(i)
            f = encode(D.grid(a[0], a[1]))
            cache[i] = f
        }
        return f
    }

    Timer {
        interval: 42
        repeat: true
        running: root.running
        onTriggered: {
            root.phase = (root.phase + 1 + Visualizer.bass * 1.6) % D.LOOP
            root.index = Math.floor(root.phase)
            root.url = root.frame(root.index)
            root.ticks++
        }
    }
}
