import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    icon: Net.type === "wifi" ? "󰖩" : (Net.type === "ethernet" ? "󰈀" : "󰖪")
    tip: Net.online ? (Net.type === "wifi" ? "Wi-Fi" : "Wired") + " connected\nClick: Wi-Fi and Bluetooth, right click: all connections" : "Offline"
    iconColor: Net.online ? Theme.accent : Theme.red
    label: Net.online ? "" : "offline"
    onClicked: Store.toggleOn("network", QsWindow.window ? QsWindow.window.screen : null)
    onRightClicked: Quickshell.execDetached(["torus-launch", "nm-connection-editor"])
}
