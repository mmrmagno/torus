pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs

Singleton {
    id: root

    property var popups: []
    property var deadlines: ({})

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
        interval: 250
        repeat: true
        running: root.popups.length > 0
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
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true
            if (!Store.dnd || n.urgency === NotificationUrgency.Critical) {
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
