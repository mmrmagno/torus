import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    id: chip

    icon: "󰏘"
    tip: "Theme: flavour, accent, wallpaper"
    onClicked: Store.toggleFrom("theme", chip)
}
