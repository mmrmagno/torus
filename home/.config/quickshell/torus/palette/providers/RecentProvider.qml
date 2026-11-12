import QtQuick
import Quickshell
import Quickshell.Io

Provider {
    id: root
    key: "recent"
    name: "Recent files"
    glyph: "󰋚"
    prefix: "r "
    help: "files you opened lately"
    inAll: true

    property var items: []

    function opened() {
        if (!proc.running)
            proc.running = true
    }

    function results(term, scoped) {
        return items
    }

    Process {
        id: proc
        command: ["torus-recent", "40"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {}
                root.items = text.split("\n").filter(l => l).map(l => {
                    const path = l.split("\t")[1] || ""
                    if (!path || seen[path])
                        return null
                    seen[path] = true
                    const dir = path.slice(0, path.lastIndexOf("/")) || "/"
                    return { id: "rf:" + path, kind: "file", glyph: "󰈔", title: path.split("/").pop(), sub: path.replace(root.home, "~") + "  ·  " + l.slice(0, 10), enter: "open",
                        act: () => Quickshell.execDetached(["torus-launch", "xdg-open", path]),
                        ctrl: { label: "open the folder", act: () => Quickshell.execDetached(["torus-launch", "xdg-open", dir]) },
                        alt: { label: "copy path", act: () => Quickshell.execDetached(["wl-copy", "--", path]) } }
                }).filter(x => x).slice(0, 40)
            }
        }
    }
}
