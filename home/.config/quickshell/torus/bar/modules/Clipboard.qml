import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    icon: "󰅌"
    onClicked: Quickshell.execDetached(["torus-menu", "clipboard"])
    onRightClicked: Quickshell.execDetached(["torus-menu", "clipmanager"])
}
