import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Provider {
    id: root
    key: "calc"
    name: "Calculator"
    glyph: "󰃬"
    prefix: "="
    help: "math and units, also without the =: 2*21, 5 km to mi"
    smart: true
    ranked: true

    property var calc: []
    property var history: []

    function wants(term, d) {
        return d.math
    }

    function copy(text) {
        Quickshell.execDetached(["wl-copy", "--", text.replace(/−/g, "-")])
    }

    function results(term, scoped) {
        if (scoped && term === "")
            return history.map(h => ({ id: "ch", kind: "calc", glyph: "󰋚", title: h.r, sub: h.q, enter: "copy", act: () => root.copy(h.r) }))
        return calc
    }

    function reset() {
        calc = []
    }

    function settle(term) {
        if (term === "")
            return
        proc.asked = term
        proc.exec(["qalc", "-t", "--", term])
    }

    Process {
        id: proc
        property string asked: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (proc.asked !== Commands.term)
                    return
                const r = text.trim()
                const asked = proc.asked
                root.calc = r === "" ? [] : [{ id: "calc", kind: "calc", glyph: "󰃬", title: r, sub: asked + " =", enter: "copy", act: () => {
                    root.history = [{ q: asked, r: r }].concat(root.history.filter(h => h.q !== asked)).slice(0, 15)
                    root.copy(r)
                }, ctrl: { label: "copy with the question", act: () => root.copy(asked + " = " + r) } }]
            }
        }
    }
}
