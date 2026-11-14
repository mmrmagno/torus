pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    readonly property string thumbs: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/torus/clip"
    readonly property string pinDir: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/torus/pins"
    readonly property string seenPath: Store.stateDir + "/clip-seen.json"

    property var entries: []
    property var pins: []
    property var shown: []
    property string filter: ""
    property string kindFilter: "all"
    property int limit: 50
    property int matches: 0
    property bool manage: false
    property var marked: ({})
    property int markedCount: 0
    property string armed: ""
    property var thumbReady: ({})
    property bool thumbsKnown: false
    property var seen: ({})
    property bool seenFresh: false
    property var hashes: ({})
    property var queue: []
    property bool listOk: false
    readonly property string decoderKey: decoder.key
    property real openedAt: 0
    property int openMs: -1
    property real filterMs: -1
    property real filterMax: 0
    property real applyMs: 0
    property string raw: ""
    property string lastQuery: ""
    property string lastKind: ""
    property var lastEntries: null
    property var lastPins: null
    property var lastPool: []

    readonly property ListModel rows: ListModel {}
    property var rowKeys: []
    property var rowMeta: []

    onFilterChanged: { limit = 50; sync() }
    onKindFilterChanged: { limit = 50; sync() }
    onLimitChanged: sync()

    function refresh() {
        if (!lister.running)
            lister.running = true
    }

    function reload() {
        pinFile.reload()
        hashes = ({})
        raw = ""
        refresh()
    }

    function classify(e) {
        if (e.image)
            return { kind: "image" }
        const t = e.text.trim()
        let m = /^#?([0-9a-f]{6}|[0-9a-f]{3})$/i.exec(t)
        if (m && (t.startsWith("#") || /[a-f]/i.test(m[1]) && /[0-9]/.test(m[1])))
            return { kind: "color", color: "#" + m[1] }
        m = /^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/i.exec(t)
        if (m)
            return { kind: "color", color: Qt.rgba(m[1] / 255, m[2] / 255, m[3] / 255, 1).toString() }
        m = /^(https?):\/\/([^\/\s]+)(\S*)$/i.exec(t)
        if (m)
            return { kind: "link", host: m[2].replace(/^www\./, ""), rest: m[3] }
        if (/^[^\s@]+@[^\s@]+\.[a-z]{2,}$/i.test(t))
            return { kind: "email" }
        if (/^(~|\/)[^\s]*$/.test(t) && t.length > 1)
            return { kind: "path" }
        if (/[{};]|=>|\(\)|^\s*(const|let|var|function|def|import|export|return|if|for|fn|pub|package|class|#include|SELECT|sudo|git|cd|ls|echo)\b/.test(t))
            return { kind: "code" }
        return { kind: "text" }
    }

    readonly property string bounds: " \t/_-.:@"

    function rank(q, ws, s) {
        const at = s.indexOf(q)
        if (at >= 0)
            return 40 + q.length * 6 + (at === 0 || bounds.indexOf(s[at - 1]) >= 0 ? 12 : 0) - Math.min(10, at / 8)
        if (ws.length > 1) {
            let i = 0, sc = 30, first = -1
            for (let n = 0; n < ws.length; n++) {
                const w = ws[n]
                const k = s.indexOf(w, i)
                if (k < 0) {
                    sc = -1
                    break
                }
                if (first < 0)
                    first = k
                sc += w.length * 5 + (k === 0 || bounds.indexOf(s[k - 1]) >= 0 ? 8 : 0)
                i = k + w.length
            }
            if (sc >= 0)
                return sc - Math.min(10, first / 8)
        }
        let i = 0, last = -2, sc = 0, first = -1, count = 0
        for (let n = 0; n < q.length; n++) {
            const c = q[n]
            if (c === " ")
                continue
            const j = s.indexOf(c, i)
            if (j < 0)
                return -1
            if (first < 0)
                first = j
            sc += 1 + (j === last + 1 ? 5 : 0) + (j === 0 || bounds.indexOf(s[j - 1]) >= 0 ? 3 : 0)
            last = j
            i = j + 1
            count++
        }
        return count ? sc - (last - first - count) * 0.15 - Math.min(5, first / 12) : -1
    }

    function words(q, s) {
        const ws = q.split(" ").filter(w => w)
        const pos = []
        let i = 0
        for (const w of ws) {
            const at = s.indexOf(w, i)
            if (at < 0)
                return null
            for (let k = 0; k < w.length; k++)
                pos.push(at + k)
            i = at + w.length
        }
        return { pos: pos }
    }

    function fuzzy(q, s) {
        if (q.indexOf(" ") > 0) {
            const w = words(q, s)
            if (w)
                return w
        }
        const at = s.indexOf(q)
        if (at >= 0) {
            const pos = []
            for (let k = 0; k < q.length; k++)
                pos.push(at + k)
            const start = at === 0 || bounds.indexOf(s[at - 1]) >= 0
            return { score: 40 + q.length * 6 + (start ? 12 : 0) - Math.min(10, at / 8), pos: pos }
        }
        const pos = []
        let i = 0, last = -2, score = 0
        for (let n = 0; n < q.length; n++) {
            const c = q[n]
            if (c === " ")
                continue
            const j = s.indexOf(c, i)
            if (j < 0)
                return null
            let sc = 1
            if (j === last + 1)
                sc += 5
            if (j === 0 || bounds.indexOf(s[j - 1]) >= 0)
                sc += 3
            score += sc
            pos.push(j)
            last = j
            i = j + 1
        }
        if (!pos.length)
            return null
        return { score: score - (last - pos[0] - pos.length) * 0.15 - Math.min(5, pos[0] / 12), pos: pos }
    }

    function groupOf(id) {
        const t = seen[id] || 0
        if (!t)
            return "Older"
        const d = new Date()
        d.setHours(0, 0, 0, 0)
        if (t >= d.getTime())
            return "Today"
        return t >= d.getTime() - 86400000 ? "Yesterday" : "Older"
    }

    function pinEntries() {
        return pins.map(p => {
            const e = { key: "p:" + p.file, id: "", line: "", text: p.text, image: p.image ? "file://" + pinDir + "/" + p.file : "", pinned: true, file: p.file, hash: p.hash || "" }
            return Object.assign(e, classify(e))
        })
    }

    function pinIndex() {
        const files = {}, hs = {}
        for (const p of pins) {
            files[p.file] = true
            if (p.hash)
                hs[p.hash] = true
        }
        return { files: files, hashes: hs }
    }

    function hiddenByPin(e, idx) {
        return idx.files[e.pinFile] === true || (hashes[e.line] !== undefined && idx.hashes[hashes[e.line]] === true)
    }

    function kindOk(e) {
        return kindFilter === "all" || e.kind === kindFilter || (kindFilter === "text" && (e.kind === "email" || e.kind === "path"))
    }

    function sync() {
        const t0 = Date.now()
        const q = filter.toLowerCase().trim()
        const idx = pinIndex()
        let pinned = pinEntries().filter(kindOk)
        let hist
        if (q !== "" && lastQuery !== "" && q.startsWith(lastQuery) && lastKind === kindFilter && lastEntries === entries && lastPins === pins)
            hist = lastPool
        else
            hist = entries.filter(e => kindOk(e) && !hiddenByPin(e, idx))
        if (q === "") {
            lastQuery = ""
        }
        if (q !== "") {
            const n = Math.max(1, entries.length)
            const ws = q.split(" ").filter(w => w)
            const score = (list, recency) => {
                const out = []
                for (let i = 0; i < list.length; i++) {
                    const e = list[i]
                    const r = rank(q, ws, e.low || (e.low = e.text.toLowerCase()))
                    if (r >= 0)
                        out.push({ src: e, score: r + (recency ? 8 * (1 - (e.at || 0) / n) : 0) })
                }
                return out
            }
            const marked = r => Object.assign({}, r.src, { marks: (fuzzy(q, r.src.low) || { pos: [] }).pos })
            const ps = score(pinned, false)
            const hs = score(hist, true)
            lastPool = hs.map(r => r.src)
            hs.sort((a, b) => b.score - a.score)
            pinned = ps.map(marked)
            const total = hs.length
            hist = hs.slice(0, limit).map(marked)
            hist.total = total
            lastQuery = q
            lastKind = kindFilter
            lastEntries = entries
            lastPins = pins
        }
        matches = pinned.length + (hist.total !== undefined ? hist.total : hist.length)
        const target = pinned.map(e => Object.assign({}, e, { group: "Pinned" }))
            .concat(hist.slice(0, limit).map(e => Object.assign({}, e, { group: q === "" ? groupOf(e.id) : "Matches" })))
        const t1 = Date.now()
        apply(target)
        shown = target
        applyMs = Date.now() - t1
        filterMs = Date.now() - t0
        filterMax = Math.max(filterMax, filterMs)
    }

    function flat(e) {
        return {
            key: e.key, text: e.text, kind: e.kind || "text", image: e.image || "", pinned: e.pinned === true,
            swatch: e.color ? String(e.color) : "", host: e.host || "", rest: e.rest || "", group: e.group || "",
            marks: (e.marks || []).join(","), line: e.line || "", file: e.file || ""
        }
    }

    function apply(target) {
        let moved = 0
        for (let i = 0; i < target.length && moved <= 12; i++)
            if (i >= rowKeys.length || rowKeys[i] !== target[i].key)
                moved++
        if (moved > 12) {
            const n = Math.min(rows.count, target.length)
            for (let i = 0; i < n; i++)
                rows.set(i, flat(target[i]))
            if (rows.count > target.length)
                rows.remove(target.length, rows.count - target.length)
            else if (target.length > n)
                rows.append(target.slice(n).map(flat))
            rowKeys = target.map(e => e.key)
            rowMeta = target.map(e => ({ marks: (e.marks || []).join(","), group: e.group || "", text: e.text }))
            return
        }
        const want = {}
        for (const e of target)
            want[e.key] = true
        const keys = rowKeys
        const meta = rowMeta
        for (let i = keys.length - 1; i >= 0; i--)
            if (!want[keys[i]]) {
                rows.remove(i)
                keys.splice(i, 1)
                meta.splice(i, 1)
            }
        for (let i = 0; i < target.length; i++) {
            const e = target[i]
            const marks = (e.marks || []).join(",")
            const group = e.group || ""
            if (i < keys.length && keys[i] === e.key) {
                if (meta[i].marks !== marks) {
                    rows.setProperty(i, "marks", marks)
                    meta[i].marks = marks
                }
                if (meta[i].group !== group) {
                    rows.setProperty(i, "group", group)
                    meta[i].group = group
                }
                if (meta[i].text !== e.text) {
                    rows.setProperty(i, "text", e.text)
                    meta[i].text = e.text
                }
                continue
            }
            const j = keys.indexOf(e.key, i + 1)
            const f = flat(e)
            if (j >= 0) {
                rows.move(j, i, 1)
                keys.splice(i, 0, keys.splice(j, 1)[0])
                meta.splice(i, 0, meta.splice(j, 1)[0])
                rows.set(i, f)
            } else {
                rows.insert(i, f)
                keys.splice(i, 0, e.key)
                meta.splice(i, 0, {})
            }
            meta[i] = { marks: marks, group: group, text: e.text }
        }
    }

    function entryAt(i) {
        return i >= 0 && i < shown.length ? shown[i] : null
    }

    function copy(entry) {
        if (!entry)
            return
        if (entry.pinned)
            Quickshell.execDetached(["sh", "-c", "wl-copy < \"$1\"", "sh", pinDir + "/" + entry.file])
        else
            Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" | cliphist decode | wl-copy", "sh", entry.line])
        Store.sound("tick")
        Store.setOpen("clip", false)
    }

    function togglePin(entry) {
        if (!entry)
            return
        Store.sound("tick")
        if (entry.pinned) {
            pins = pins.filter(p => p.file !== entry.file)
            savePins()
            Quickshell.execDetached(["sh", "-c", "cliphist store < \"$1\" && rm -f -- \"$1\"", "sh", pinDir + "/" + entry.file])
            sync()
            return
        }
        if (pinner.running)
            return
        const file = Qt.md5(entry.line) + ".pin"
        pinner.pending = { file: file, text: entry.text, image: entry.image !== "" }
        pinner.command = ["sh", "-c", "umask 077; mkdir -p \"$2\" && chmod 700 \"$2\" && printf '%s\\n' \"$1\" | cliphist decode > \"$2/$3\" && md5sum < \"$2/$3\" | cut -d' ' -f1", "sh", entry.line, pinDir, file]
        pinner.running = true
    }

    function movePin(from, to) {
        if (from < 0 || to < 0 || from >= pins.length || to >= pins.length || from === to)
            return
        const p = pins.slice()
        const it = p.splice(from, 1)[0]
        p.splice(to, 0, it)
        pins = p
        savePins()
        sync()
    }

    function savePins() {
        Quickshell.execDetached(["sh", "-c", "umask 077; printf '%s' \"$2\" > \"$1.tmp\" && mv -f \"$1.tmp\" \"$1\"", "sh", pinDir + ".json", JSON.stringify(pins)])
    }

    function remove(entry) {
        if (!entry)
            return "none"
        if (entry.pinned && armed !== entry.key) {
            armed = entry.key
            return "armed"
        }
        armed = ""
        Store.sound("delete")
        if (entry.pinned) {
            togglePin(entry)
            return "deleted"
        }
        entries = entries.filter(e => e.key !== entry.key)
        sync()
        deleteLines([entry.line])
        return "deleted"
    }

    function deleteLines(lines) {
        if (!lines.length)
            return
        Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$@\" | cliphist delete", "sh"].concat(lines))
    }

    function toggleMark(entry) {
        if (!entry)
            return
        const m = Object.assign({}, marked)
        if (m[entry.key])
            delete m[entry.key]
        else
            m[entry.key] = true
        marked = m
        markedCount = Object.keys(m).length
        armed = ""
    }

    function clearMarks() {
        marked = ({})
        markedCount = 0
    }

    function deleteMarked() {
        const all = pinEntries().concat(entries).filter(e => marked[e.key])
        if (!all.length)
            return "none"
        if (all.some(e => e.pinned) && armed !== "marked") {
            armed = "marked"
            return "armed"
        }
        armed = ""
        Store.sound("delete")
        const gone = {}
        for (const e of all)
            gone[e.key] = true
        const pinFiles = all.filter(e => e.pinned).map(e => e.file)
        if (pinFiles.length) {
            pins = pins.filter(p => pinFiles.indexOf(p.file) < 0)
            savePins()
            Quickshell.execDetached(["sh", "-c", "cd \"$1\" && shift && rm -f -- \"$@\"", "sh", pinDir].concat(pinFiles))
        }
        const lines = all.filter(e => !e.pinned).map(e => e.line)
        entries = entries.filter(e => !gone[e.key])
        clearMarks()
        sync()
        deleteLines(lines)
        return "deleted"
    }

    function clearKind(kind) {
        const tag = "clear:" + kind
        if (armed !== tag) {
            armed = tag
            return "armed"
        }
        armed = ""
        Store.sound("delete")
        if (kind === "all") {
            entries = []
            sync()
            Quickshell.execDetached(["cliphist", "wipe"])
            return "deleted"
        }
        const drop = entries.filter(e => e.kind === kind || (kind === "text" && (e.kind === "email" || e.kind === "path")))
        const gone = {}
        for (const e of drop)
            gone[e.key] = true
        entries = entries.filter(e => !gone[e.key])
        sync()
        deleteLines(drop.map(e => e.line))
        return "deleted"
    }

    function wantThumb(line) {
        if (!line)
            return
        const k = Qt.md5(line)
        if (!thumbReady[k] && queue.indexOf(line) < 0 && decoder.key !== k)
            queue.push(line)
        pump()
    }

    function thumbLost(line) {
        const k = Qt.md5(line)
        if (!thumbReady[k])
            return
        const r = Object.assign({}, thumbReady)
        delete r[k]
        thumbReady = r
        wantThumb(line)
    }

    function pump() {
        if (decoder.running || !queue.length)
            return
        const line = queue.shift()
        if (thumbReady[Qt.md5(line)]) {
            Qt.callLater(root.pump)
            return
        }
        decoder.key = Qt.md5(line)
        decoder.command = ["sh", "-c", "umask 077; mkdir -p \"$2\" && chmod 700 \"$2\" && printf '%s\\n' \"$1\" | cliphist decode > \"$2/$3.tmp\" && [ -s \"$2/$3.tmp\" ] && mv -f \"$2/$3.tmp\" \"$2/$3.img\" || { rm -f \"$2/$3.tmp\"; exit 1; }", "sh", line, thumbs, decoder.key]
        decoder.running = true
    }

    function thumbFor(line) {
        const k = Qt.md5(line)
        return thumbReady[k] ? "file://" + thumbs + "/" + k + ".img" : ""
    }

    function parse() {
        const out = []
        const now = Date.now()
        const s = Object.assign({}, seen)
        const ids = {}
        let changed = false
        for (const line of raw.split("\n")) {
            const tab = line.indexOf("\t")
            if (tab < 0)
                continue
            const id = line.slice(0, tab)
            const preview = line.slice(tab + 1)
            const m = preview.match(/^\[\[ binary data .* (png|jpg|jpeg|webp|bmp|gif) (\d+)x(\d+) \]\]$/)
            const md5 = Qt.md5(line)
            const e = { key: "h:" + id, id: id, line: line, at: out.length, pinFile: md5 + ".pin", text: m ? "image " + m[2] + "x" + m[3] : preview, image: m ? "file://" + thumbs + "/" + md5 + ".img" : "", pinned: false }
            Object.assign(e, classify(e))
            out.push(e)
            ids[id] = true
            if (s[id] === undefined) {
                s[id] = seenFresh ? 0 : now
                changed = true
            }
        }
        for (const id in s)
            if (!ids[id]) {
                delete s[id]
                changed = true
            }
        seenFresh = false
        seen = s
        if (changed)
            seenFile.setText(JSON.stringify(s))
        entries = out
        sync()
        pruneThumbs()
        findDuplicates()
    }

    function pruneThumbs() {
        if (prune.running || (entries.length === 0 && !listOk))
            return
        prune.command = ["sh", "-c", "cd \"$1\" 2>/dev/null || exit 0; shift; for f in *.img; do [ -e \"$f\" ] || continue; case \" $* \" in *\" ${f%.img} \"*) echo \"${f%.img}\" ;; *) rm -f \"$f\" ;; esac; done", "sh", thumbs].concat(entries.filter(e => e.image).map(e => e.pinFile.slice(0, 32)))
        prune.running = true
    }

    function findDuplicates() {
        if (hasher.running)
            return
        const previews = {}
        for (const p of pins)
            previews[p.text] = (previews[p.text] || 0) + 1
        for (const e of entries)
            previews[e.text] = (previews[e.text] || 0) + 1
        const want = entries.filter(e => previews[e.text] > 1 && hashes[e.line] === undefined).map(e => e.line)
        if (!want.length) {
            dropDuplicates()
            return
        }
        hasher.command = ["sh", "-c", "for l in \"$@\"; do printf '%s\\t%s\\n' \"$(printf '%s\\n' \"$l\" | cliphist decode | md5sum | cut -d' ' -f1)\" \"$l\"; done", "sh"].concat(want)
        hasher.running = true
    }

    function dropDuplicates() {
        const pinHash = {}
        for (const p of pins)
            if (p.hash)
                pinHash[p.hash] = true
        const kept = {}
        const drop = []
        for (const e of entries) {
            const h = hashes[e.line]
            if (!h)
                continue
            if (pinHash[h] || kept[h])
                drop.push(e.line)
            else
                kept[h] = true
        }
        if (!drop.length)
            return
        entries = entries.filter(e => drop.indexOf(e.line) < 0)
        sync()
        deleteLines(drop)
    }

    function hashPins() {
        const missing = pins.filter(p => !p.hash).map(p => pinDir + "/" + p.file)
        if (missing.length && !pinHasher.running) {
            pinHasher.command = ["md5sum", "--"].concat(missing)
            pinHasher.running = true
        }
    }

    Connections {
        target: Store
        function onOpenChanged() {
            if (Store.isOpen("clip")) {
                if (root.openedAt === 0) {
                    root.openedAt = Date.now()
                    root.openMs = -1
                    root.filterMax = 0
                }
                root.refresh()
            } else {
                root.openedAt = 0
                root.armed = ""
                root.manage = false
                root.clearMarks()
            }
        }
    }

    Process {
        id: lister
        command: ["cliphist", "list"]
        onRunningChanged: if (running) root.listOk = false
        onExited: code => {
            root.listOk = code === 0
            if (root.listOk && root.entries.length === 0)
                root.pruneThumbs()
        }
        stdout: StdioCollector {
            onStreamFinished: {
                if (text === root.raw && root.entries.length > 0) {
                    root.pruneThumbs()
                    return
                }
                root.raw = text
                root.parse()
                if (!root.thumbsKnown) {
                    root.thumbsKnown = true
                    root.pruneThumbs()
                }
            }
        }
    }

    Process {
        id: decoder
        property string key: ""
        onExited: code => {
            if (code === 0) {
                const r = Object.assign({}, root.thumbReady)
                r[key] = true
                root.thumbReady = r
            }
            key = ""
            Qt.callLater(root.pump)
        }
    }

    Process {
        id: prune
        stdout: StdioCollector {
            onStreamFinished: {
                const r = {}
                for (const k of text.split("\n"))
                    if (k)
                        r[k] = true
                root.thumbReady = r
            }
        }
    }

    Process {
        id: hasher
        stdout: StdioCollector {
            onStreamFinished: {
                const h = Object.assign({}, root.hashes)
                for (const l of text.split("\n")) {
                    const tab = l.indexOf("\t")
                    if (tab > 0)
                        h[l.slice(tab + 1)] = l.slice(0, tab)
                }
                root.hashes = h
                root.dropDuplicates()
            }
        }
    }

    Process {
        id: pinHasher
        stdout: StdioCollector {
            onStreamFinished: {
                const by = {}
                for (const l of text.split("\n")) {
                    const m = l.match(/^([0-9a-f]{32})\s+(?:.*\/)?([^\/]+)$/)
                    if (m)
                        by[m[2]] = m[1]
                }
                root.pins = root.pins.map(p => Object.assign({}, p, { hash: p.hash || by[p.file] || "" }))
                root.savePins()
                root.findDuplicates()
            }
        }
    }

    Process {
        id: pinner
        property var pending: null
        stdout: StdioCollector {
            onStreamFinished: {
                const h = text.trim()
                if (pinner.pending && /^[0-9a-f]{32}$/.test(h))
                    pinner.pending.hash = h
            }
        }
        onExited: code => {
            if (code === 0 && pending) {
                root.pins = [pending].concat(root.pins.filter(p => p.file !== pending.file))
                root.savePins()
                root.sync()
                root.findDuplicates()
            }
            pending = null
        }
    }

    FileView {
        id: pinFile
        path: root.pinDir + ".json"
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                root.pins = JSON.parse(text())
            } catch (e) {
                root.pins = []
            }
            Qt.callLater(root.hashPins)
        }
        onLoadFailed: root.pins = []
    }

    FileView {
        id: seenFile
        path: root.seenPath
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                root.seen = JSON.parse(text())
            } catch (e) {
                root.seen = ({})
            }
        }
        onLoadFailed: root.seenFresh = true
    }

    Component.onCompleted: refresh()
}
