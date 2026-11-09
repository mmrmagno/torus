pragma Singleton
import QtQuick
import Quickshell
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
            for (const old of root.list.slice()) {
                if (old !== n && root.keyOf(old) === key) {
                    count += root.repeats[old.id] || 1
                    old.dismiss()
                }
            }
            const r = Object.assign({}, root.repeats)
            r[n.id] = count
            root.repeats = r
            n.tracked = true
            root.remember(n)
            const recent = Date.now() - (root.lastFlash[key] || 0) < 10000
            const lf = Object.assign({}, root.lastFlash)
            lf[key] = Date.now()
            root.lastFlash = lf
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
