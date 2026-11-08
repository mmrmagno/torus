import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    icon: "󰸉"
    onClicked: Quickshell.execDetached(["torus-menu", "wallpaper"])
    onScrolled: delta => Quickshell.execDetached(["qs", "-c", "torus", "ipc", "call", "torus", delta > 0 ? "wallpaperNext" : "wallpaperPrev"])
}
