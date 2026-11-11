import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Provider {
    id: root
    key: "files"
    name: "Files"
    glyph: "󰈔"
    prefix: "/"
    help: "find files in your home; a path like ~/dev/ lists that folder"
    smart: true
    ranked: true

    property var files: []

    function wants(term, d) {
        return d.path
    }

    function pathOf(term) {
        if (term.startsWith("~"))
            return root.home + term.slice(1)
        if (term.startsWith("/"))
            return term
        return term.includes("/") ? "/" + term : ""
    }

    function tilde(p) {
        return p === root.home || p.startsWith(root.home + "/") ? "~" + p.slice(root.home.length) : p
    }

    function row(p, dir, exact) {
        const parent = dir ? p : p.slice(0, p.lastIndexOf("/")) || "/"
        const r = {
            id: "f:" + p, kind: dir ? "folder" : "file", glyph: dir ? "󰉋" : "󰈔", title: exact ? tilde(p) : p.split("/").filter(x => x).pop() + (dir ? "/" : ""), sub: tilde(p),
            enter: "open", act: () => Quickshell.execDetached(["xdg-open", p]),
            ctrl: { label: "terminal here", act: () => Quickshell.execDetached(["kitty", "--directory", parent]) },
            alt: { label: "copy path", act: () => Quickshell.execDetached(["wl-copy", "--", p]) }
        }
        if (dir && !exact) {
            r.keep = true
            r.enter = "go in"
            const t = tilde(p)
            r.act = () => Commands.put((Commands.mode === "files" && t.startsWith("~") ? "/" : "") + t + "/")
        }
        return r
    }

    function results(term, scoped) {
        return files
    }

    function reset() {
        files = []
    }

    function settle(term) {
        const p = pathOf(term)
        if (p !== "") {
            lsProc.asked = term
            lsProc.exec(["sh", "-c", 'p=$1; d=${p%/*}; [ -e "$p" ] && { [ -d "$p" ] && echo "=d" || echo "=f"; }; cd "${d:-/}" 2> /dev/null && ls -1Ap | head -400', "sh", p])
        } else if (term.length >= 2) {
            fdProc.asked = term
            fdProc.exec(["fd", "-F", "--type", "f", "--max-results", "40", "--color", "never", "--", term, root.home])
        }
    }

    Process {
        id: fdProc
        property string asked: ""
        stdout: StdioCollector {
            onStreamFinished: if (fdProc.asked === Commands.term) root.files = text.split("\n").filter(l => l).slice(0, 40).map(p => root.row(p, false, false))
        }
    }

    Process {
        id: lsProc
        property string asked: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (lsProc.asked !== Commands.term)
                    return
                const p = root.pathOf(lsProc.asked)
                const dir = p.slice(0, p.lastIndexOf("/")) || ""
                const base = p.slice(p.lastIndexOf("/") + 1).toLowerCase()
                let lines = text.split("\n").filter(l => l)
                const out = []
                if (lines.length > 0 && lines[0].startsWith("=")) {
                    if (base !== "" && base !== "." && base !== "..")
                        out.push(root.row(p, lines[0] === "=d", true))
                    lines.shift()
                }
                if (out.length > 0)
                    lines = lines.filter(n => n.replace(/\/$/, "").toLowerCase() !== base)
                const names = lines.filter(n => base === "" || n.toLowerCase().startsWith(base)).concat(lines.filter(n => base !== "" && !n.toLowerCase().startsWith(base) && n.toLowerCase().includes(base)))
                for (const n of names.slice(0, 40)) {
                    const isDir = n.endsWith("/")
                    out.push(root.row(dir + "/" + n.replace(/\/$/, ""), isDir, false))
                }
                if (base === "" && out.length === 0)
                    out.push(root.row(dir || "/", true, true))
                root.files = out
            }
        }
    }
}
