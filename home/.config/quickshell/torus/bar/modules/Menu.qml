import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    icon: "󰣇"
    tip: "Apps\nRight click: dashboard"
    onClicked: Quickshell.execDetached(["torus-menu", "drun"])
    onRightClicked: Store.toggleOn("dashboard", QsWindow.window ? QsWindow.window.screen : null)
}
