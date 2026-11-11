import QtQuick
import Quickshell
import Quickshell.Io
import "../route.mjs" as R

Provider {
    id: root
    key: "pass"
    name: "Proton Pass"
    section: "Pass"
    glyph: "󰟵"
    prefix: "p "
    help: "item names only; Enter lists its fields, a copy clears itself"
    secret: true
    ranked: true

    property var items: []
    property string loadState: ""
    property real loaded: 0
    property var pick: null
    property var fields: null
    readonly property int clearAfter: Number(Quickshell.env("TORUS_PASS_CLEAR") || 30)

    function entered() {
        if (proc.running || (loadState === "ready" && Date.now() - loaded < 300000))
            return
        loadState = "loading"
        proc.running = true
    }

    function reset() {
        pick = null
        fields = null
    }

    function open(it) {
        fields = null
        pick = it
        fieldsProc.asked = it.iid
        fieldsProc.exec(["torus-pass", "fields", it.sid, it.iid])
    }

    function copyName(it) {
        Quickshell.execDetached(["wl-copy", "--", it.title])
    }

    function results(term, scoped) {
        if (pick) {
            const it = pick
            if (fields === null)
                return [{ id: "ph", kind: "hint", glyph: "󰔟", title: "Checking " + it.title + "…", sub: "looking up which fields it has", act: () => {} }]
            const openApp = { id: "po", kind: "app", glyph: "󰟵", title: "Open Proton Pass", sub: "for anything else in this item", enter: "open", act: () => Quickshell.execDetached(["proton-pass"]) }
            const name = { id: "pn", kind: "field", glyph: "󰈚", title: "Name", sub: it.title + " · copy", enter: "copy", act: () => root.copyName(it) }
            if (fields.length === 0)
                return [name, openApp]
            const labels = [["password", "󰌾", "Password"], ["email", "󰇮", "Email"], ["username", "󰀄", "Username"], ["totp", "󰔟", "One-time code"],
                ["urls", "󰖟", "Website"], ["number", "󰆛", "Card number"], ["cvv", "󰆛", "CVV"], ["cardholder_name", "󰀄", "Cardholder"],
                ["expiration_date", "󰃭", "Expiry"], ["private_key", "󰌆", "Private key"], ["public_key", "󰌆", "Public key"], ["note", "󰎚", "Note"]]
            return labels.filter(f => fields.indexOf(f[0]) >= 0).map(f => ({
                id: "pf", kind: "field", glyph: f[1], title: f[2], sub: it.title + " · copy, clears in " + clearAfter + " s", enter: "copy",
                act: () => Quickshell.execDetached(["torus-pass", "copy", it.sid, it.iid, f[0], String(root.clearAfter)])
            })).concat([name, openApp])
        }
        if (loadState === "error")
            return [{ id: "ph", kind: "hint", glyph: "󰟵", title: "Proton Pass is locked", sub: "run pass-cli login in a terminal, then try again", act: () => {} }]
        if (items.length === 0)
            return [{ id: "ph", kind: "hint", glyph: "󰟵", title: "Loading your vaults…", sub: "names only, nothing is shown or saved", act: () => {} }]
        const out = items.map(p => ({ id: "p", kind: "pass", keep: true, glyph: "󰟵", title: p.title, sub: p.vault, sid: p.sid, iid: p.iid, enter: "show fields", act: null }))
        for (const it of out) {
            const item = it
            item.act = () => root.open(item)
            item.ctrl = { label: "copy the name", act: () => root.copyName(item) }
        }
        return term === "" ? out : R.rank(out, term, {}, 0).map(x => x.it)
    }

    Process {
        id: fieldsProc
        property string asked: ""
        stdout: StdioCollector {
            onStreamFinished: if (root.pick && root.pick.iid === fieldsProc.asked) root.fields = text.split("\n").filter(l => l)
        }
    }

    Process {
        id: proc
        command: ["torus-pass", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const items = text.split("\n").filter(l => l).map(l => {
                    const f = l.split("\t")
                    return { sid: f[0], iid: f[1], vault: f[2], title: f[3] }
                }).filter(p => p.title)
                root.items = items
                root.loadState = items.length > 0 ? "ready" : "error"
                root.loaded = Date.now()
            }
        }
    }
}
