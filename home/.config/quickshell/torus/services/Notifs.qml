pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs

Singleton {
    id: root

    property var popups: []
    property var deadlines: ({})
    property var repeats: ({})
    property var history: []
    property var lastFlash: ({})
    property int quietFrom: 0
    property int quietTo: 6
    property bool quietActive: false
    property bool dndBeforeQuiet: false
    property var arrived: ({})
    property var muted: ({})
    property string filter: ""
    property real awaySince: 0
    property var awayItems: []
    property real lastAway: 0
    readonly property bool away: Store.locked || Focus.running

    function isMuted(app) {
        return (muted[app] || 0) > Date.now()
    }

    function mute(app, minutes) {
        const m = {}
        for (const k in muted)
            if (muted[k] > Date.now())
                m[k] = muted[k]
        if (minutes > 0)
            m[app] = Date.now() + minutes * 60000
        else
            delete m[app]
        muted = m
        muteFile.setText(JSON.stringify(m))
    }

    function untilTomorrow() {
        const d = new Date()
        d.setDate(d.getDate() + 1)
        d.setHours(8, 0, 0, 0)
        return Math.ceil((d.getTime() - Date.now()) / 60000)
    }

    function matches(n) {
        const q = filter.trim().toLowerCase()
        if (q === "")
            return true
        return ((n.appName || "") + " " + (n.summary || "") + " " + (n.body || "")).toLowerCase().includes(q)
    }

    onAwayChanged: {
        if (away) {
            awaySince = Date.now()
            awayItems = []
        } else if (awayItems.length > 0) {
            lastAway = awaySince
            const apps = {}
            for (const a of awayItems)
                apps[a] = (apps[a] || 0) + 1
            const top = Object.keys(apps).sort((a, b) => apps[b] - apps[a])
            if (awayItems.length >= 3 && Ai.status === "online") {
                summaryOffer.lines = history.filter(h => h.time >= awaySince).slice(0, 40).map(h => "- " + h.app + ": " + h.summary + (h.body ? " (" + h.body.slice(0, 160) + ")" : ""))
                summaryOffer.command = ["notify-send", "-a", "torus", "-i", "notifications", "-t", "60000", "-A", "sum=Summarize", "While you were away: " + awayItems.length + " notifications", "the local model can sum them up"]
                summaryOffer.running = true
            }
            Island.flash("notification", { summary: "While you were away: " + awayItems.length + (awayItems.length === 1 ? " notification" : " notifications"), body: top.slice(0, 3).map(a => a + (apps[a] > 1 ? " ×" + apps[a] : "")).join(", ") + (top.length > 3 ? " and more" : ""), app: "torus", icon: "notifications", image: "" }, 6000)
        }
    }

    Process {
        id: summaryOffer
        property var lines: []
        stdout: StdioCollector {
            onStreamFinished: if (text.trim() === "sum") Ai.summarize(summaryOffer.lines)
        }
    }

    FileView {
        id: muteFile
        path: Store.stateDir + "/notif-mute.json"
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                root.muted = JSON.parse(text())
            } catch (e) {
                root.muted = {}
            }
        }
    }

    function keyOf(n) {
        return (n.appName || "") + "\u0001" + (n.summary || "") + "\u0001" + (n.body || "")
    }

    function inQuiet(h) {
        return quietFrom <= quietTo ? (h >= quietFrom && h < quietTo) : (h >= quietFrom || h < quietTo)
    }

    function checkQuiet() {
        const now = inQuiet(new Date().getHours())
        if (now && !quietActive) {
            dndBeforeQuiet = Store.dnd
            quietActive = true
            Store.dnd = true
        } else if (!now && quietActive) {
            quietActive = false
            if (Store.dnd)
                Store.dnd = dndBeforeQuiet
        }
    }

    property var otp: ({})

    function otpOf(text) {
        const t = (text || "").replace(/<[^>]*>/g, " ")
        if (!/(code|otp|verif|passcode|one[- ]?time|2fa|two[- ]factor|sign[- ]?in|login|bestätigung|sicherheits)/i.test(t))
            return ""
        const m = t.match(/(?:^|[^\d])(\d{6,8})(?!\d)/) || t.match(/(?:^|[^\d])(\d{3})[ -](\d{3})(?!\d)/)
        return m ? (m[2] ? m[1] + m[2] : m[1]) : ""
    }

    function copyOtp(code) {
        if (!/^\d{6,8}$/.test(code))
            return
        Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | wl-copy --sensitive; sleep 90; [ \"$(wl-paste -n 2>/dev/null)\" = \"$1\" ] && wl-copy --clear", "sh", code])
        Island.flash("osd", { icon: "󰌆", label: "code copied, clears in 90 s", value: -1 }, 1600)
    }

    function remember(n) {
        const code = otpOf((n.summary || "") + " " + (n.body || ""))
        if (code !== "")
            otp = { code: code, app: n.appName || "", until: Date.now() + 120000 }
        let plain = (n.body || "").replace(/<[^>]*>/g, "")
        if (code !== "")
            plain = plain.split(code).join("••••••").replace(code.slice(0, 3) + " " + code.slice(3), "••• •••").replace(code.slice(0, 3) + "-" + code.slice(3), "•••-•••")
        history = [{ app: n.appName || "", summary: n.summary || "", body: plain, time: Date.now() }].concat(history).slice(0, 200)
    }

    function lifetime(n) {
        if (n.expireTimeout > 0)
            return n.expireTimeout * 1000
        return n.urgency === NotificationUrgency.Low ? 5000 : 10000
    }

    function hold(n) {
        if (n.urgency === NotificationUrgency.Critical)
            return
        const d = Object.assign({}, deadlines)
        d[n.id] = Date.now() + 2500
        deadlines = d
    }
    readonly property var list: server.trackedNotifications.values
    readonly property int count: list.length
    property var expanded: ({})
    function threads(items) {
        const out = []
        const byKey = {}
        for (const n of items) {
            const k = (n.summary || "").trim()
            if (k !== "" && byKey[k]) {
                byKey[k].earlier.push(n)
                continue
            }
            const t = { notif: n, earlier: [] }
            if (k !== "")
                byKey[k] = t
            out.push(t)
        }
        return out
    }

    readonly property var groups: {
        const order = []
        const byApp = {}
        for (let i = list.length - 1; i >= 0; i--) {
            const n = list[i]
            if (!matches(n))
                continue
            const k = n.appName || "unknown"
            if (!byApp[k]) {
                byApp[k] = { app: k, icon: n.appIcon, items: [] }
                order.push(byApp[k])
            }
            byApp[k].items.push(n)
        }
        for (const g of order)
            g.threads = threads(g.items)
        return order
    }

    property int replyTarget: -1
    function openReply(n) {
        if (!n)
            return
        const e = Object.assign({}, expanded)
        e[n.appName || "unknown"] = true
        expanded = e
        replyTarget = n.id
        dismissPopup(n)
        Store.setOpen("center", true)
    }

    function toggleGroup(app) {
        const e = Object.assign({}, expanded)
        e[app] = !e[app]
        expanded = e
    }

    function clearGroup(app) {
        for (const n of list.filter(x => (x.appName || "unknown") === app))
            n.dismiss()
    }

    onCountChanged: Store.notifCount = count

    function dismissPopup(n) {
        popups = popups.filter(p => p !== n)
        const d = Object.assign({}, deadlines)
        delete d[n.id]
        deadlines = d
    }

    function ago(n) {
        const t = arrived[n.id]
        if (!t)
            return ""
        const m = Math.floor((Date.now() - t) / 60000)
        return m < 1 ? "now" : m < 60 ? m + " min" : Math.floor(m / 60) + " h"
    }

    property real lastSound: 0
    readonly property var ownSound: /^(nm-applet|networkmanager|discord|vesktop|webcord|armcord|signal|telegram|slack|teams|microsoft teams|element|whatsapp|zapzap|steam|thunderbird|spotify)/i

    function playFor(n) {
        if (!Store.sounds || Store.dnd || Store.gamemode)
            return
        const h = n.hints || {}
        if (h["suppress-sound"] === true || n.urgency === NotificationUrgency.Low)
            return
        if (ownSound.test(n.appName || "") || ownSound.test(n.desktopEntry || ""))
            return
        const recent = Object.values(Store.soundAt).reduce((a, b) => Math.max(a, b), 0)
        if (Date.now() - lastSound < 1500 || Date.now() - recent < 1000)
            return
        lastSound = Date.now()
        const ev = h["sound-file"] ? "file:" + h["sound-file"] : (h["sound-name"] ? "name:" + h["sound-name"] : (n.urgency === NotificationUrgency.Critical ? "critical" : "notify"))
        if (!Feel.soundOn("notify"))
            return
        Quickshell.execDetached(["torus-sound", "play", ev, String(Feel.soundVolume)])
    }

    function clearAll() {
        if (list.length > 0)
            Store.sound("delete")
        for (const n of list.slice())
            n.dismiss()
        popups = []
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.checkQuiet()
    }

    Timer {
        interval: 250
        repeat: true
        running: root.popups.length > 0 && Object.keys(root.deadlines).length > 0
        onTriggered: {
            const now = Date.now()
            for (const n of root.popups.slice())
                if (root.deadlines[n.id] !== undefined && root.deadlines[n.id] <= now)
                    root.dismissPopup(n)
        }
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        actionIconsSupported: true
        bodyMarkupSupported: true
        bodySupported: true
        inlineReplySupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            const key = root.keyOf(n)
            let count = 1
            const r = Object.assign({}, root.repeats)
            for (const old of root.list.slice()) {
                if (old !== n && root.keyOf(old) === key) {
                    count += r[old.id] || 1
                    delete r[old.id]
                    old.expire()
                }
            }
            const live = {}
            for (const x of root.list)
                live[x.id] = true
            for (const id in r)
                if (!live[id])
                    delete r[id]
            r[n.id] = count
            root.repeats = r
            n.tracked = true
            root.remember(n)
            const recent = Date.now() - (root.lastFlash[key] || 0) < 10000
            const lf = {}
            for (const k in root.lastFlash)
                if (Date.now() - root.lastFlash[k] < 60000)
                    lf[k] = root.lastFlash[k]
            lf[key] = Date.now()
            root.lastFlash = lf
            const ar = {}
            for (const x of root.list)
                if (root.arrived[x.id])
                    ar[x.id] = root.arrived[x.id]
            ar[n.id] = Date.now()
            root.arrived = ar
            if (root.away)
                root.awayItems = root.awayItems.concat([n.appName || "unknown"])
            if (root.isMuted(n.appName || "unknown") && n.urgency !== NotificationUrgency.Critical) {
                n.closed.connect(() => root.dismissPopup(n))
                return
            }
            root.playFor(n)
            const loud = n.urgency === NotificationUrgency.Critical || n.actions.length > 0
            const quiet = Store.dnd || (Store.gamemode && Play.hold)
            if (!loud && !quiet && !recent)
                Island.notify(n)
            else if (loud && (!quiet || n.urgency === NotificationUrgency.Critical)) {
                if (n.urgency !== NotificationUrgency.Critical) {
                    const d = Object.assign({}, root.deadlines)
                    d[n.id] = Date.now() + root.lifetime(n)
                    root.deadlines = d
                }
                root.popups = [n].concat(root.popups).slice(0, 5)
            }
            n.closed.connect(() => root.dismissPopup(n))
        }
    }
}
