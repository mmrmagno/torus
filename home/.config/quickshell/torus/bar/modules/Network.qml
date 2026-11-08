import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    icon: Net.type === "wifi" ? "󰖩" : (Net.type === "ethernet" ? "󰈀" : "󰖪")
    iconColor: Net.online ? Theme.accent : Theme.red
    label: Net.online ? "" : "offline"
    onClicked: Quickshell.execDetached(["nm-connection-editor"])
}
