import QtQuick
import Quickshell
import Quickshell.Io
import "../route.mjs" as R

Provider {
    id: root
    key: "web"
    name: "Web"
    section: "Open"
    glyph: "󰖟"
    help: "type a link to open it, or words to search the web"
    smart: true
    ranked: true

    function wants(term, d) {
        return d.url !== ""
    }

    function engines() {
        const out = []
        for (const line of engineFile.text().split("\n")) {
            const f = line.split("|").map(x => x.trim())
            if (f.length >= 3 && f[1] && f[2].indexOf("%s") >= 0)
                out.push({ glyph: f[0] || "󰖟", name: f[1].charAt(0).toUpperCase() + f[1].slice(1), url: f[2] })
        }
        return out
    }

    function results(term, scoped) {
        const url = R.detect(term).url
        if (url !== "")
            return [{ id: "url", kind: "url", glyph: "󰖟", title: url, sub: "open in the browser", enter: "open", act: () => Quickshell.execDetached(["torus-launch", "xdg-open", url]), ctrl: { label: "copy link", act: () => Quickshell.execDetached(["wl-copy", "--", url]) } }]
        if (!scoped)
            return []
        const q = term.trim()
        return engines().map(e => ({ id: "web:" + e.name, kind: "url", glyph: e.glyph, title: q === "" ? e.name : e.name + ": " + q, sub: q === "" ? "type what to search" : "search in the browser", enter: "search", act: () => {
                if (q !== "")
                    Quickshell.execDetached(["torus-launch", "xdg-open", e.url.replace("%s", encodeURIComponent(q))])
            } }))
    }

    FileView {
        id: engineFile
        path: root.home + "/.local/share/torus/websearch.lst"
        blockLoading: true
        printErrors: false
    }
}
