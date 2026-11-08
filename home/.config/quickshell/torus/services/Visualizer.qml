pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property bool playing: Mpris.players.values.some(p => p.isPlaying)
    property var values: []
    property real bass: 0
    property real level: 0
    property int frames: 0

    Process {
        id: cava
        running: root.playing
        command: ["cava", "-p", Quickshell.env("HOME") + "/.config/cava/torus.conf"]
        stdout: SplitParser {
            onRead: line => {
                const v = line.split(";").filter(s => s !== "").map(Number)
                if (v.length === 0)
                    return
                root.values = v
                const b = (v[0] + v[1] + v[2] + v[3]) / 400
                root.bass = root.bass * 0.55 + b * 0.45
                root.level = v.reduce((a, x) => a + x, 0) / (v.length * 100)
                root.frames++
            }
        }
        onRunningChanged: if (!running) {
            root.values = []
            root.bass = 0
            root.level = 0
        }
    }
}
