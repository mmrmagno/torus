import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    readonly property int count: Store.notifCount
    icon: Store.dnd ? "󰂛" : (count > 0 ? "󰂚" : "󰂜")
    iconColor: Store.dnd ? Theme.overlay : Theme.accent
    label: count > 0 ? count : ""
    onClicked: Store.toggle("center")
    onRightClicked: Store.dnd = !Store.dnd
}
