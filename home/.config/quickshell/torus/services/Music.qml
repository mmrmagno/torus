pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs

Singleton {
    id: root

    property var queue: []
    property int pos: -1
    property bool paused: true
    property real time: 0
    property real duration: 0
    property bool wanted: false
    property int lastRid: 0
    property int tries: 0
    property real askedStart: 0
    property var waiting: ({})
    property var backlog: []
    property var kept: ({})
    property var keptOrder: []
    property var late: ({})
    readonly property var current: pos >= 0 && pos < queue.length ? queue[pos] : null
    property var servers: []
    property string folder: "~/Music"
    property int localCount: 0
    property bool indexing: false
    property string lastError: ""
    readonly property var node: Pipewire.nodes.values.find(n => n.isStream && n.isSink && n.name === "torus-music") || null
    readonly property var voice: node && node.audio ? node.audio : idleVoice
    signal queueReplacing
    signal queueReplaced
    signal coverLanded(string source, string coverId, string path)

    PwObjectTracker { objects: root.node ? [root.node] : [] }

    QtObject {
        id: idleVoice
        property real volume: 1
        property bool muted: false
        property bool hearing: false
        onVolumeChanged: if (!hearing) volumeSend.restart()
        onMutedChanged: if (!hearing) root.send(["volume", muted ? "mute" : "unmute"])
        function hear(v, m) {
            if (volumeSend.running)
                return
            hearing = true
            volume = v
            muted = m
            hearing = false
        }
    }

    Timer {
        id: volumeSend
        interval: 120
        onTriggered: root.send(["volume", String(idleVoice.volume)])
    }

    Connections {
        target: root.node ? root.node.audio : null
        function onVolumesChanged() { idleVoice.hear(root.node.audio.volume, root.node.audio.muted) }
        function onMutedChanged() { idleVoice.hear(root.node.audio.volume, root.node.audio.muted) }
    }

    function follow(on) {
        wanted = on
        if (sock.connected)
            line({ follow: on })
        else if (on)
            connect()
    }

    Socket {
        id: sock
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000") + "/torus-music/ctl.sock"
        parser: SplitParser { onRead: data => root.heard(data) }
        onConnectionStateChanged: connected ? root.online() : root.offline()
        onError: root.offline()
    }

    function line(obj) {
        sock.write(JSON.stringify(obj) + "\n")
        sock.flush()
    }

    function online() {
        tries = 0
        knock.stop()
        if (wanted)
            line({ follow: true })
        const out = backlog
        backlog = []
        for (const o of out)
            line(o)
    }

    function offline() {
        if (sock.connected)
            return
        const queued = backlog.map(o => String(o.rid))
        const gone = []
        for (const k in waiting) {
            if (queued.indexOf(k) < 0) {
                gone.push(waiting[k])
                delete waiting[k]
            }
        }
        for (const done of gone)
            done({ error: "torus music stopped", more: false })
        if (backlog.length > 0)
            startDaemon()
        if (backlog.length > 0 || wanted)
            knock.restart()
    }

    function startDaemon() {
        if (Date.now() - askedStart < 3000)
            return
        askedStart = Date.now()
        Quickshell.execDetached(["systemctl", "--user", "start", "--no-block", "torus-music.service"])
    }

    function fail(why) {
        const gone = waiting
        waiting = ({})
        backlog = []
        for (const k in gone)
            gone[k]({ error: why, more: false })
    }

    function connect() {
        sock.connected = false
        sock.connected = true
    }

    Timer {
        id: knock
        interval: root.backlog.length > 0 ? 60 : 1500
        onTriggered: {
            if (sock.connected)
                return
            if (root.backlog.length > 0 && ++root.tries > 130) {
                root.tries = 0
                root.fail("torus music did not start")
                if (root.wanted)
                    restart()
                return
            }
            root.connect()
        }
    }

    function send(args, done) {
        const rid = ++lastRid
        if (done)
            waiting[rid] = done
        const o = { rid: rid, args: args }
        if (sock.connected) {
            line(o)
            return
        }
        backlog = backlog.concat([o])
        if (!knock.running)
            connect()
    }

    function heard(data) {
        let m
        try { m = JSON.parse(data) } catch (e) { return }
        if (m.cover) {
            late[m.cover.source + "\u0001" + m.cover.coverId] = m.cover.path
            coverLanded(m.cover.source, m.cover.coverId, m.cover.path)
            return
        }
        if (m.rid !== undefined) {
            const done = waiting[m.rid]
            if (!m.more)
                delete waiting[m.rid]
            if (done)
                done(m)
            return
        }
        if (m.pos === undefined)
            return
        if (m.queue !== undefined && JSON.stringify(m.queue) !== JSON.stringify(root.queue)) {
            root.queueReplacing()
            root.queue = m.queue
            root.queueReplaced()
        }
        root.pos = m.pos
        root.paused = m.paused
        root.time = m.time
        root.duration = m.duration
        if (!root.node && m.volume !== undefined)
            idleVoice.hear(m.volume, m.muted === true)
    }

    Component {
        id: job
        Process {
            id: p
            property var done: null
            property string input: ""
            stdinEnabled: input !== ""
            onStarted: if (input !== "") { write(input + "\n"); input = ""; stdinEnabled = false }
            stdout: StdioCollector {
                onStreamFinished: {
                    let m = null
                    try { m = JSON.parse(text) } catch (e) { m = { error: "torus-music gave no answer" } }
                    if (p.done)
                        p.done(m || {})
                    p.destroy()
                }
            }
        }
    }

    function run(args, done, input) {
        const p = job.createObject(root, { command: ["torus-music"].concat(args), done: done || null, input: input || "" })
        p.running = true
    }

    // done may run up to three times: what is known now, then what the daemon has, then the fresh answer
    function browse(args, done) {
        const key = args.join("\u0001")
        const before = kept[key]
        if (before)
            done(before.m, true, true)
        send(args, m => {
            if (m.error) {
                done(m, true, false)
                return
            }
            const rest = m.more === true
            if (m.same) {
                done(kept[key] ? kept[key].m : {}, false, rest)
                return
            }
            delete m.rid
            delete m.more
            const text = JSON.stringify(m)
            const changed = !kept[key] || kept[key].text !== text
            if (changed) {
                kept[key] = { m: m, text: text }
                keptOrder.push(key)
                if (keptOrder.length > 60) {
                    const old = keptOrder.shift()
                    if (keptOrder.indexOf(old) < 0)
                        delete kept[old]
                }
            }
            done(kept[key].m, changed, rest)
        })
    }

    function warm() {
        send(["warm"])
    }

    function lateCover(r) {
        return r && !r.cover && r.coverId ? late[r.source + "\u0001" + r.coverId] || "" : ""
    }

    function fileUrl(p) {
        return p ? "file://" + p.split("/").map(x => encodeURIComponent(x)).join("/") : ""
    }

    function act(args) {
        send(args, m => {
            if (m.error) {
                lastError = m.error
                Island.flash("osd", { icon: "󰎆", label: m.error, value: -1 }, 3000)
            }
        })
    }

    function playRef(kind, row, start, mode) {
        act([mode || "play", kind, row.source, row.id].concat(start !== undefined ? [String(start)] : []))
    }

    function playRows(rows, start, mode) {
        const list = rows.filter(r => r.kind === "track").slice(0, 300)
        if (list.length === 0)
            return
        const slim = list.map(r => ({ source: r.source, id: r.id, path: r.path || "", title: r.title, artist: r.artist, album: r.album, albumId: r.albumId || "", artistId: r.artistId || "", seconds: r.seconds || 0, cover: r.cover || "", coverId: r.coverId || "", starred: !!r.starred }))
        act([mode || "play", "rows", JSON.stringify(slim), String(Math.max(0, start || 0))])
    }

    function play(row, list, mode) {
        if (!row)
            return
        if (row.kind === "track") {
            if (mode && mode !== "play")
                playRows([row], 0, mode)
            else {
                const tracks = (list || [row]).filter(r => r.kind === "track")
                playRows(tracks, Math.max(0, tracks.indexOf(row)), "play")
            }
        } else {
            playRef(row.kind, row, undefined, mode)
        }
    }

    function control(c) {
        if (c === "toggle" && queue.length > 0)
            paused = !paused
        act([c])
    }

    function loadServers(done) {
        send(["setup"], m => {
            if (!m.error) {
                root.servers = m.servers || []
                root.folder = m.folder || "~/Music"
                root.localCount = m.local || 0
                root.indexing = !!m.indexing
            }
            if (done)
                done(m)
        })
    }

    function fmt(s) {
        s = Math.max(0, Math.floor(s || 0))
        const m = Math.floor(s / 60)
        const h = Math.floor(m / 60)
        const ss = String(s % 60).padStart(2, "0")
        return h > 0 ? h + ":" + String(m % 60).padStart(2, "0") + ":" + ss : m + ":" + ss
    }
}
