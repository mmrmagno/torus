import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

import Quickshell.Wayland

Chip {
    id: root
    icon: Store.stayAwake ? "󰅶" : "󰾪"
    tip: Store.stayAwake ? "Staying awake on every screen (click to allow sleep)" : "Click to keep the screens awake"
    iconColor: Store.stayAwake ? Theme.peach : Theme.overlay
    onClicked: Store.stayAwake = !Store.stayAwake

    IdleInhibitor {
        window: root.QsWindow.window
        enabled: Store.stayAwake
    }
}
