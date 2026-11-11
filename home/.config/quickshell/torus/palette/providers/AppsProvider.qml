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
            a.push({ id: "app:" + e.id, kind: "app", title: e.name, sub: e.genericName || e.comment || "", keys: (e.keywords || []).join(" "), icon: Quickshell.iconPath(e.icon, true), enter: "launch", act: () => entry.execute() })
        }
        a.sort((x, y) => x.title.localeCompare(y.title))
        items = a
    }

    function results(term, scoped) {
        return items
    }
}
