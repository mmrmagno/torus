pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    readonly property string thumbs: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/torus/clip"
    property var entries: []
    property var pins: []
    readonly property string pinDir: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/torus/pins"
    property string filter: ""
    property string raw: ""
    readonly property var shown: {
        const q = filter.toLowerCase()
        const pinned = pins.map(p => ({ id: "pin:" + p.file, line: "", text: p.text, image: p.image ? "file://" + pinDir + "/" + p.file : "", pinned: true, file: p.file }))
        const taken = {}
        for (const p of pins)
            taken[p.file] = true
        const all = pinned.map(p => Object.assign(p, classify(p))).concat(entries.filter(e => !taken[Qt.md5(e.line) + ".pin"])).filter(e => kindFilter === "all" || e.kind === kindFilter || (kindFilter === "text" && (e.kind === "email" || e.kind === "path")))
        if (q === "")
            return all
        return all.filter(e => {
            const t = e.text.toLowerCase()
            let i = 0
            for (const c of q) {
                i = t.indexOf(c, i)
                if (i < 0)
                    return false
                i++
            }
            return true
        })
    }

    function refresh() {
        lister.running = true
    }

    function copy(entry) {
        if (entry.pinned)
            Quickshell.execDetached(["sh", "-c", "wl-copy < \"$1\"", "sh", pinDir + "/" + entry.file])
        else
            Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" | cliphist decode | wl-copy", "sh", entry.line])
        Store.setOpen("clip", false)
    }

    function togglePin(entry) {
        if (!entry)
            return
        if (entry.pinned) {
            pins = pins.filter(p => p.file !== entry.file)
            savePins()
            Quickshell.execDetached(["rm", "-f", "--", pinDir + "/" + entry.file])
            return
        }
        if (pinner.running)
            return
        const file = Qt.md5(entry.line) + ".pin"
        pinner.pending = { file: file, text: entry.text, image: entry.image !== "" }
        pinner.command = ["sh", "-c", "umask 077; mkdir -p \"$2\" && chmod 700 \"$2\" && printf '%s\\n' \"$1\" | cliphist decode > \"$2/$3\"", "sh", entry.line, pinDir, file]
        pinner.running = true
    }

    function savePins() {
        pinFile.setText(JSON.stringify(pins))
        Quickshell.execDetached(["chmod", "600", "--", pinDir + ".json"])
    }

    function remove(entry) {
        if (entry.pinned) {
            togglePin(entry)
            return
        }
        remover.command = ["sh", "-c", "printf '%s\\n' \"$1\" | cliphist delete", "sh", entry.line]
        remover.running = true
    }

    Connections {
        target: Store
        function onOpenChanged() {
            if (Store.isOpen("clip") && !lister.running) {
                root.filter = ""
                root.refresh()
            }
        }
    }

    Process {
        id: lister
        command: ["sh", "-c", "mkdir -p \"$1\" && cliphist list | head -n 200", "sh", root.thumbs]
        stdout: StdioCollector {
            onStreamFinished: {
                root.raw = text
                thumbnailer.running = true
            }
        }
    }

    property string kindFilter: "all"

    function classify(e) {
        if (e.image)
            return { kind: "image" }
        const t = e.text.trim()
        let m = /^#?([0-9a-f]{6}|[0-9a-f]{3})$/i.exec(t)
        if (m && (t.startsWith("#") || /[a-f]/i.test(m[1]) && /[0-9]/.test(m[1])))
            return { kind: "color", color: "#" + m[1] }
        m = /^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/i.exec(t)
        if (m)
            return { kind: "color", color: Qt.rgba(m[1] / 255, m[2] / 255, m[3] / 255, 1).toString() }
        m = /^(https?):\/\/([^\/\s]+)(\S*)$/i.exec(t)
        if (m)
            return { kind: "link", host: m[2].replace(/^www\./, ""), rest: m[3] }
        if (/^[^\s@]+@[^\s@]+\.[a-z]{2,}$/i.test(t))
            return { kind: "email" }
        if (/^(~|\/)[^\s]*$/.test(t) && t.length > 1)
            return { kind: "path" }
        if (/[{};]|=>|\(\)|^\s*(const|let|var|function|def|import|export|return|if|for|fn|pub|package|class|#include|SELECT|sudo|git|cd|ls|echo)\b/.test(t))
            return { kind: "code" }
        return { kind: "text" }
    }

    function parse() {
        const out = []
        for (const line of raw.split("\n")) {
            const tab = line.indexOf("\t")
            if (tab < 0)
                continue
            const id = line.slice(0, tab)
            const preview = line.slice(tab + 1)
            const m = preview.match(/^\[\[ binary data .* (png|jpg|jpeg|webp|bmp|gif) (\d+)x(\d+) \]\]$/)
            const e = { id: id, line: line, text: m ? "image " + m[2] + "x" + m[3] : preview, image: m ? "file://" + thumbs + "/" + Qt.md5(line) + ".img" : "" }
            Object.assign(e, classify(e))
            out.push(e)
        }
        entries = out
    }

    Process {
        id: thumbnailer
        command: ["sh", "-c", "cd \"$1\" || exit 0; printf '%s' \"$2\" | grep -E '\\[\\[ binary data .* (png|jpg|jpeg|webp|bmp|gif) ' > .want || true; keep=; while IFS= read -r l; do f=\"$(printf '%s' \"$l\" | md5sum | cut -d' ' -f1).img\"; keep=\"$keep $f\"; [ -s \"$f\" ] || printf '%s\\n' \"$l\" | cliphist decode > \"$f\"; done < .want; rm -f .want; for f in *.img; do case \" $keep \" in *\" $f \"*) ;; *) rm -f \"$f\" ;; esac; done", "sh", root.thumbs, root.raw]
        onExited: root.parse()
    }

    Process {
        id: pinner
        property var pending: null
        onExited: code => {
            if (code === 0 && pending) {
                root.pins = [pending].concat(root.pins.filter(p => p.file !== pending.file))
                root.savePins()
            }
            pending = null
        }
    }

    FileView {
        id: pinFile
        path: root.pinDir + ".json"
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                root.pins = JSON.parse(text())
            } catch (e) {
                root.pins = []
            }
        }
    }

    Process {
        id: remover
        onExited: root.refresh()
    }
}
