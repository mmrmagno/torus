import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    icon: "󰏘"
    tip: "Theme: flavour, accent, wallpaper"
    onClicked: Store.toggleOn("theme", QsWindow.window ? QsWindow.window.screen : null)
}
