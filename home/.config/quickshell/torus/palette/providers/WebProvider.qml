import QtQuick
import Quickshell
import "../route.mjs" as R

Provider {
    key: "web"
    name: "Web"
    section: "Open"
    glyph: "󰖟"
    help: "type a link to open it"
    scoped: false
    smart: true
    ranked: true

    function wants(term, d) {
        return d.url !== ""
    }

    function results(term, scoped) {
        const url = R.detect(term).url
        return url === "" ? [] : [{ id: "url", kind: "url", glyph: "󰖟", title: url, sub: "open in the browser", enter: "open", act: () => Quickshell.execDetached(["torus-launch", "xdg-open", url]), ctrl: { label: "copy link", act: () => Quickshell.execDetached(["wl-copy", "--", url]) } }]
    }
}
