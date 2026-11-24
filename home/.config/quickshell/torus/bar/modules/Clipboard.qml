import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    id: chip

    icon: "󰅌"
    tip: "Clipboard history\nRight click: select and delete"
    onClicked: {
        Clip.manage = false
        Store.toggleFrom("clip", chip)
    }
    onRightClicked: {
        if (!Store.isOpen("clip"))
            Store.openFrom("clip", chip)
        Clip.manage = true
    }
}
