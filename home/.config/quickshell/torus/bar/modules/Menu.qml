import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    id: chip

    icon: "󰣇"
    tip: "Apps\nRight click: dashboard"
    onClicked: Quickshell.execDetached(["torus-menu", "drun"])
    onRightClicked: Store.toggleFrom("dashboard", chip)
}
