import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    icon: "󰏘"
    tip: "Accent colour, click to pick"
    onClicked: Quickshell.execDetached(["torus-menu", "accent"])
}
