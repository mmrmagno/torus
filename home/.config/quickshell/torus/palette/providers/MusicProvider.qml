import QtQuick
import Quickshell
import qs.services

Provider {
    id: root
    key: "music"
    name: "Music"
    glyph: "󰎆"
    prefix: "m "
    help: "songs, albums and artists from the local library and Subsonic; Enter plays, Ctrl queues, Alt plays next"

    property var hits: []
    property string hitsFor: ""
    property var rows: []

    function results(term, scoped) {
        return hits
    }

    function reset() {
        if (Commands.mode !== "music" || Commands.term.trim().length < 2) {
            hits = []
            rows = []
            hitsFor = ""
        }
    }

    function eager(term) {
        ask(term, "local")
    }

    function settle(term) {
        ask(term, "all")
    }

    function ask(term, src) {
        const q = term.trim()
        if (q.length < 2)
            return
        Music.browse(["search", q, src], (m, changed, rest) => {
            if (q !== Commands.term.trim() || Commands.mode !== "music" || m.error || (src === "local" && root.hitsFor === q))
                return
            const found = (m.tracks || []).slice(0, 12).concat((m.albums || []).slice(0, 6), (m.artists || []).slice(0, 4))
            if (src === "local" && found.length === 0)
                return
            if (src === "all")
                root.hitsFor = q
            root.rows = found
            root.show()
        })
    }

    function show() {
        const next = rows.map(r => root.row(r))
        if (next.map(r => r.id + r.icon).join() !== hits.map(r => r.id + r.icon).join())
            hits = next
    }

    Connections {
        target: Music
        enabled: root.rows.length > 0
        function onCoverLanded(source, coverId, path) {
            if (root.rows.some(r => !r.cover && r.source === source && String(r.coverId || "") === coverId))
                covers.restart()
        }
    }

    Timer {
        id: covers
        interval: 120
        onTriggered: root.show()
    }

    function row(r) {
        const what = r.kind === "track" ? "song" : r.kind
        const sub = [what, r.kind === "track" ? r.artist : r.kind === "album" ? r.artist : "", r.source === "local" ? "" : r.source].filter(x => x).join(", ")
        return {
            id: "music:" + r.source + ":" + r.kind + ":" + r.id, kind: "music", glyph: r.kind === "artist" ? "󰠃" : r.kind === "album" ? "󰀥" : "󰎆",
            icon: Music.fileUrl(r.cover || Music.lateCover(r)), title: r.title, sub: sub, enter: "play",
            act: () => Music.play(r, [r]),
            ctrl: { label: "add to the queue", act: () => Music.play(r, null, "add") },
            alt: { label: "play next", act: () => Music.play(r, null, "next") }
        }
    }
}
