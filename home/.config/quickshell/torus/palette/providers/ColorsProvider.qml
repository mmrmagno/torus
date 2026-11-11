import QtQuick
import Quickshell
import Quickshell.Io
import "../route.mjs" as R

Provider {
    id: root
    key: "colors"
    name: "Colors"
    glyph: "󰏘"
    prefix: "#"
    help: "colors you picked; type a hex to get it as rgb or hsl"
    ranked: true

    function copy(t) {
        Quickshell.execDetached(["wl-copy", "--", t])
    }

    function row(h, title) {
        return { id: "c:" + h, kind: "color", swatch: h, title: title || h, sub: R.rgb(h) + "  ·  " + R.hsl(h), enter: "copy hex",
            act: () => root.copy(h), ctrl: { label: "copy rgb", act: () => root.copy(R.rgb(h)) }, alt: { label: "copy hsl", act: () => root.copy(R.hsl(h)) } }
    }

    function entered() {
        colorsFile.reload()
    }

    function results(term, scoped) {
        const q = term.toLowerCase().replace("#", "")
        const typed = R.hex(term)
        const out = colorsFile.text().split("\n").filter(l => /^#[0-9a-f]{6}$/.test(l) && l.includes(q) && l !== typed).map(h => row(h))
        if (typed !== "")
            out.unshift(row(typed))
        if (q === "")
            out.unshift({ id: "a:pick2", kind: "action", glyph: "󰈊", title: "Pick a color from the screen", sub: "copies the hex", enter: "pick", act: () => Quickshell.execDetached(["sh", "-c", "sleep 0.3; torus-pick"]) })
        return out
    }

    FileView {
        id: colorsFile
        path: root.stateDir + "/colors"
        printErrors: false
    }
}
