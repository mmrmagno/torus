import QtQuick
import Quickshell
import Quickshell.Io

Provider {
    id: root
    key: "glyphs"
    name: "Glyphs"
    glyph: "󰀻"
    help: "find a Nerd Font icon by name, Enter copies it"
    ranked: true

    function results(term, scoped) {
        const words = term.toLowerCase().split(/[\s_-]+/).filter(w => w)
        const out = []
        for (const line of glyphFile.text().split("\n")) {
            const tab = line.indexOf("\t")
            if (tab < 0)
                continue
            const name = line.slice(tab + 1)
            if (!words.every(w => name.toLowerCase().includes(w)))
                continue
            const ch = line.slice(0, tab)
            out.push({ id: "g:" + name, kind: "glyph", glyph: ch, title: name, sub: "copy", enter: "copy", act: () => Quickshell.execDetached(["wl-copy", "--", ch]) })
            if (out.length >= 60)
                break
        }
        return out
    }

    FileView {
        id: glyphFile
        path: root.home + "/.local/share/torus/glyph.db"
        blockLoading: true
        printErrors: false
    }
}
