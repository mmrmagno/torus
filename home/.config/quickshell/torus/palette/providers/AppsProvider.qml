import QtQuick
import Quickshell

Provider {
    id: root
    key: "apps"
    name: "Apps"
    glyph: "󰀻"
    help: "installed applications"
    inAll: true

    property var items: []

    function opened() {
        const a = []
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay)
                continue
            const entry = e
            const web = String(e.id).startsWith("torus-webapp-")
            a.push({ id: "app:" + e.id, kind: "app", chip: web ? "web app" : "", remove: web ? String(e.id).replace(/^torus-webapp-/, "").replace(/\.desktop$/, "") : "", title: e.name, sub: e.genericName || e.comment || "", keys: (e.keywords || []).join(" "), icon: Quickshell.iconPath(e.icon, true), enter: "launch", act: () => Quickshell.execDetached(["torus-launch", "--dir", entry.workingDirectory || Quickshell.env("HOME")].concat(entry.runInTerminal ? ["kitty", "-e"] : [], entry.command)) })
        }
        a.sort((x, y) => x.title.localeCompare(y.title))
        items = a
    }

    function results(term, scoped) {
        return items
    }
}
