import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Provider {
    id: root
    key: "kb"
    name: "Notes"
    glyph: "󰈙"
    prefix: "?"
    help: "search the markdown in ~/dev/kb; ? alone shows this list"
    ranked: true

    property var hits: []

    function results(term, scoped) {
        return term === "" ? Commands.helpRows() : hits
    }

    function reset() {
        hits = []
    }

    function settle(term) {
        if (term.length < 2)
            return
        proc.asked = term
        proc.exec(["rg", "-i", "-F", "-n", "--max-count", "1", "--max-columns", "160", "--glob", "*.md", "--", term, root.home + "/dev/kb"])
    }

    Process {
        id: proc
        property string asked: ""
        stdout: StdioCollector {
            onStreamFinished: if (proc.asked === Commands.term) root.hits = text.split("\n").filter(l => l).slice(0, 40).map(l => {
                const m = l.match(/^(.*?):(\d+):(.*)$/)
                if (!m)
                    return null
                const rel = m[1].replace(root.home + "/dev/kb/", "")
                return { id: "kb:" + rel, kind: "kb", glyph: "󰈙", title: m[3].trim() || rel, sub: rel + ":" + m[2], enter: "open in nvim", act: () => Quickshell.execDetached(["torus-launch", "kitty", "-e", "nvim", "+" + m[2], m[1]]),
                    ctrl: { label: "open the folder", act: () => Quickshell.execDetached(["torus-launch", "xdg-open", m[1].slice(0, m[1].lastIndexOf("/"))]) } }
            }).filter(x => x)
        }
    }
}
