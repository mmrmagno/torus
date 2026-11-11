import QtQuick
import Quickshell
import Quickshell.Io

Provider {
    id: root
    key: "emoji"
    name: "Emoji"
    glyph: "󰞅"
    prefix: ":"
    help: "find an emoji by name, Enter copies it"
    ranked: true

    function results(term, scoped) {
        const words = term.toLowerCase().split(/\s+/).filter(w => w)
        const out = []
        for (const line of emojiFile.text().split("\n")) {
            if (!line || !words.every(w => line.toLowerCase().includes(w)))
                continue
            const ch = line.split(" ")[0]
            out.push({ id: "e:" + ch, kind: "emoji", glyph: ch, title: line.slice(ch.length + 1).split(/\s+/).slice(0, 4).join(" "), sub: "copy", enter: "copy", act: () => Quickshell.execDetached(["wl-copy", "--", ch]) })
            if (out.length >= 40)
                break
        }
        return out
    }

    FileView {
        id: emojiFile
        path: root.home + "/.local/share/torus/emoji.db"
        blockLoading: true
        printErrors: false
    }
}
