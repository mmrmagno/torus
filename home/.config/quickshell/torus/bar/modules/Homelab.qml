import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    readonly property bool shown: Spire.problems > 0
    icon: "󱃾"
    iconColor: Theme.red
    label: String(Spire.problems)
    tip: "Spire: " + Spire.problems + (Spire.problems === 1 ? " problem" : " problems") + "\nClick: homelab hub (SUPER+H)"
    onClicked: Store.toggleOn("homelab", QsWindow.window ? QsWindow.window.screen : null)
}
