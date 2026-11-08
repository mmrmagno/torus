pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property var player: Mpris.players.values.find(p => p.isPlaying) || null
    readonly property string key: player ? [player.trackArtist, player.trackTitle, player.trackAlbum, Math.round(player.length)].join("|") : ""
    property var lines: []
    property string line: ""
    property string loadedKey: ""

    onKeyChanged: {
        lines = []
        line = ""
        if (!player || !player.trackTitle)
            return
        fetch.command = ["torus-lyrics", player.trackArtist || "", player.trackTitle || "", player.trackAlbum || "", String(Math.round(player.length || 0))]
        fetch.running = true
    }

    Process {
        id: fetch
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                for (const l of text.split("\n")) {
                    const m = l.match(/^\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*)$/)
                    if (m)
                        out.push({ t: parseInt(m[1]) * 60 + parseFloat(m[2]), text: m[3].replace(/<\d+:\d+(?:\.\d+)?>\s*/g, "").trim() })
                }
                root.lines = out
                root.loadedKey = root.key
            }
        }
    }

    Timer {
        interval: 250
        repeat: true
        running: root.player !== null && root.lines.length > 0
        onTriggered: {
            root.player.positionChanged()
            const pos = root.player.position
            let cur = ""
            for (const l of root.lines) {
                if (l.t > pos + 0.15)
                    break
                cur = l.text
            }
            root.line = cur
        }
    }
}
