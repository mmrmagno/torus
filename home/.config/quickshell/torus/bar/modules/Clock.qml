import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    icon: "󰥔"
    tip: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy") + "\nClick: dashboard, right click: " + (Store.clockDate ? "hide" : "show") + " date"
    label: Qt.formatDateTime(clock.date, Store.clockDate ? "ddd dd MMM  HH:mm:ss" : "HH:mm:ss")
    onClicked: Store.toggleOn("dashboard", QsWindow.window ? QsWindow.window.screen : null)
    onRightClicked: Store.setClockDate(!Store.clockDate)

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
}
