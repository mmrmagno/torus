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
            Island.flash("notification", { summary: "While you were away: " + awayItems.length + (awayItems.length === 1 ? " notification" : " notifications"), body: top.slice(0, 3).map(a => a + (apps[a] > 1 ? " ×" + apps[a] : "")).join(", ") + (top.length > 3 ? " and more" : ""), app: "torus", icon: "notifications", image: "" }, 6000)
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

    function remember(n) {
        const plain = (n.body || "").replace(/<[^>]*>/g, "")
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
        return order
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

    function clearAll() {
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
            const loud = n.urgency === NotificationUrgency.Critical || n.actions.length > 0
            if (!loud && !Store.dnd && !recent)
                Island.notify(n)
            else if (loud && (!Store.dnd || n.urgency === NotificationUrgency.Critical)) {
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
