import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    readonly property int count: Store.notifCount
    icon: Store.dnd ? "󰂛" : (count > 0 ? "󰂚" : "󰂜")
    tip: (count > 0 ? count + " notifications" : "No notifications") + (Store.dnd ? ", do not disturb" : "") + "\nRight click: do not disturb"
    iconColor: Store.dnd ? Theme.overlay : Theme.accent
    label: count > 0 ? count : ""
    onClicked: Store.toggleOn("center", QsWindow.window ? QsWindow.window.screen : null)
    onRightClicked: Store.dnd = !Store.dnd
}
