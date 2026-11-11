import QtQuick
import Quickshell
import Quickshell.Io

Provider {
    id: root
    key: "projects"
    name: "Projects"
    glyph: "󰊢"
    prefix: "d "
    help: "git repos under ~/dev; Enter terminal, Ctrl nvim, Alt the repo page"
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
        command: ["torus-projects"]
        stdout: StdioCollector {
            onStreamFinished: root.items = text.split("\n").filter(l => l).map(l => {
                const f = l.split("\t")
                const path = f[0], branch = f[1] || "", dirty = f[2] || "0", url = f[3] || ""
                const short = path.startsWith(root.home + "/") ? "~" + path.slice(root.home.length) : path
                const r = {
                    id: "d:" + path, kind: "project", glyph: "󰊢", title: path.split("/").pop(),
                    sub: short + "  ·  " + branch + (dirty === "0" ? "" : "  ·  " + dirty + " changed"), keys: short + " " + branch,
                    enter: "terminal", act: () => Quickshell.execDetached(["kitty", "--directory", path]),
                    ctrl: { label: "nvim", act: () => Quickshell.execDetached(["kitty", "--directory", path, "nvim", "."]) }
                }
                if (url !== "")
                    r.alt = { label: "repo page", act: () => Quickshell.execDetached(["xdg-open", url]) }
                return r
            })
        }
    }
}
