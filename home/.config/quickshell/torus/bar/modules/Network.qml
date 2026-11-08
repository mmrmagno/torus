import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    icon: Net.type === "wifi" ? "󰖩" : (Net.type === "ethernet" ? "󰈀" : "󰖪")
    tip: Net.online ? (Net.type === "wifi" ? "Wi-Fi" : "Wired") + " connected\nClick: connections" : "Offline"
    iconColor: Net.online ? Theme.accent : Theme.red
    label: Net.online ? "" : "offline"
    onClicked: Quickshell.execDetached(["nm-connection-editor"])
}
