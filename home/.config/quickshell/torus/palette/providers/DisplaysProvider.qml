import QtQuick
import Quickshell
import Quickshell.Io

Provider {
    id: root
    key: "displays"
    name: "Displays"
    section: "Display layouts"
    glyph: "󰍹"
    help: "saved display layouts, type display; Enter applies, Alt+Enter forgets"
    inAll: true
    scoped: false

    property var items: []

    function opened() {
        if (!proc.running)
            proc.running = true
    }

    function results(term, scoped) {
        if (!/^(dis|scr|mon|lay)/i.test(term.trim()))
            return []
        return items.map(it => ({
            id: "dl:" + it.key, kind: "layout", glyph: "󰍹", title: it.key.split(" + ").map(d => { const w = d.split(" "); return w.length >= 3 ? w[0] + " " + w[w.length - 2] : d }).join("  +  "),
            sub: it.count + (it.count === "1" ? " screen" : " screens") + (it.current ? "  ·  plugged in now" : ""), keys: "display layout screens monitors " + it.key,
            enter: "apply", act: () => Quickshell.execDetached(["torus-displays", "use", it.key]),
            alt: { label: "forget", act: () => { Quickshell.execDetached(["torus-displays", "drop", it.key]); root.items = root.items.filter(x => x.key !== it.key) } }
        }))
    }

    Process {
        id: proc
        command: ["torus-displays", "tsv"]
        stdout: StdioCollector {
            onStreamFinished: root.items = text.split("\n").filter(l => l).map(l => {
                const f = l.split("\t")
                return { key: f[0], count: f[1], current: f[2] === "current" }
            })
        }
    }
}
