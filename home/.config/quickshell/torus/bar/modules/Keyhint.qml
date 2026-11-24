import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    id: chip

    icon: "󰌌"
    tip: "Keybind cheat sheet (SUPER+/)"
    onClicked: Store.toggleFrom("cheatsheet", chip)
}
