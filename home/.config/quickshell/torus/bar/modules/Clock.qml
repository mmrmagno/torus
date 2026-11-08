import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    property bool alt: false
    icon: "󰥔"
    tip: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy") + "\nClick: dashboard, right click: show date"
    label: Qt.formatDateTime(clock.date, alt ? "ddd dd MMM  hh:mm:ss AP" : "hh:mm:ss AP")
    onClicked: Store.toggle("dashboard")
    onRightClicked: alt = !alt

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
}
