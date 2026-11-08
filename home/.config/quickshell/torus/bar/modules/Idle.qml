import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

import Quickshell.Wayland

Chip {
    id: root
    property bool inhibit: false
    icon: inhibit ? "󰅶" : "󰾪"
    iconColor: inhibit ? Theme.peach : Theme.overlay
    onClicked: inhibit = !inhibit

    IdleInhibitor {
        window: root.QsWindow.window
        enabled: root.inhibit
    }
}
