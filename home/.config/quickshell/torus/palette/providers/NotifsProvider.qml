import QtQuick
import Quickshell
import qs.services

Provider {
    key: "notifs"
    name: "Notifications"
    glyph: "󰂚"
    prefix: "n "
    help: "search past notifications, Enter copies the text"
    ranked: true

    function results(term, scoped) {
        const words = term.toLowerCase().split(/\s+/).filter(w => w)
        return Notifs.history.filter(h => words.every(w => (h.app + " " + h.summary + " " + h.body).toLowerCase().includes(w))).slice(0, 40).map(h => ({
            id: "n", kind: "notification", glyph: "󰂚", title: h.summary || h.app, sub: h.app + " · " + Qt.formatTime(new Date(h.time), "hh:mm") + (h.body ? " · " + h.body : ""),
            enter: "copy", act: () => Quickshell.execDetached(["wl-copy", "--", h.body || h.summary])
        }))
    }
}
