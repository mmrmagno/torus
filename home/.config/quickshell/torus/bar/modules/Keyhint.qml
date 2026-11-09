import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    icon: "󰌌"
    tip: "Keybind cheat sheet (SUPER+/)"
    onClicked: Store.toggleOn("cheatsheet", QsWindow.window ? QsWindow.window.screen : null)
}
