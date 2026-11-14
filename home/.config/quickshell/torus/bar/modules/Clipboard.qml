import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    icon: "󰅌"
    tip: "Clipboard history\nRight click: select and delete"
    onClicked: {
        Clip.manage = false
        Store.toggle("clip")
    }
    onRightClicked: {
        if (!Store.isOpen("clip"))
            Store.setOpen("clip", true)
        Clip.manage = true
    }
}
