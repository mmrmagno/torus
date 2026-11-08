pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    readonly property string thumbs: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/torus/clip"
    property var entries: []
    property string filter: ""
    property string raw: ""
    readonly property var shown: {
        const q = filter.toLowerCase()
        if (q === "")
            return entries
        return entries.filter(e => {
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
        Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" | cliphist decode | wl-copy", "sh", entry.line])
        Store.setOpen("clip", false)
    }

    function remove(entry) {
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

    function parse() {
        const out = []
        for (const line of raw.split("\n")) {
            const tab = line.indexOf("\t")
            if (tab < 0)
                continue
            const id = line.slice(0, tab)
            const preview = line.slice(tab + 1)
            const m = preview.match(/^\[\[ binary data .* (png|jpg|jpeg|webp|bmp|gif) (\d+)x(\d+) \]\]$/)
            out.push({ id: id, line: line, text: m ? "image " + m[2] + "x" + m[3] : preview, image: m ? "file://" + thumbs + "/" + Qt.md5(line) + ".img" : "" })
        }
        entries = out
    }

    Process {
        id: thumbnailer
        command: ["sh", "-c", "cd \"$1\" || exit 0; printf '%s' \"$2\" | grep -E '\\[\\[ binary data .* (png|jpg|jpeg|webp|bmp|gif) ' > .want || true; keep=; while IFS= read -r l; do f=\"$(printf '%s' \"$l\" | md5sum | cut -d' ' -f1).img\"; keep=\"$keep $f\"; [ -s \"$f\" ] || printf '%s\\n' \"$l\" | cliphist decode > \"$f\"; done < .want; rm -f .want; for f in *.img; do case \" $keep \" in *\" $f \"*) ;; *) rm -f \"$f\" ;; esac; done", "sh", root.thumbs, root.raw]
        onExited: root.parse()
    }

    Process {
        id: remover
        onExited: root.refresh()
    }
}
