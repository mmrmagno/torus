import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    icon: "󰣇"
    onClicked: Quickshell.execDetached(["torus-menu", "drun"])
    onRightClicked: Store.toggle("dashboard")
}
