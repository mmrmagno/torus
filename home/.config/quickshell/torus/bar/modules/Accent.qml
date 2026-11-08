import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    icon: "󰏘"
    onClicked: Quickshell.execDetached(["torus-menu", "accent"])
}
