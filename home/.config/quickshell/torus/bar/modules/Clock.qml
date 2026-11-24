import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    id: chip

    icon: Calm.active ? "󰌪" : "󰥔"
    tip: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy") + (Calm.active ? "\nCalm mode: on battery, the wallpaper rests" : "") + "\nClick: dashboard, right click: " + (Store.clockDate ? "hide" : "show") + " date"
    label: Qt.formatDateTime(clock.date, Store.clockDate ? "ddd dd MMM  HH:mm" + (Calm.active ? "" : ":ss") : (Calm.active ? "HH:mm" : "HH:mm:ss"))
    onClicked: Store.toggleFrom("dashboard", chip)
    onRightClicked: Store.setClockDate(!Store.clockDate)

    SystemClock {
        id: clock
        precision: Calm.active ? SystemClock.Minutes : SystemClock.Seconds
    }
}
