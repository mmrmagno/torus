import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    icon: "󰸉"
    tip: "Wallpaper: " + (Store.wallpaper === "donut" ? "donut" : (Store.wallpaper === "xwing" ? "X-wing" : "picture")) + "\nClick: pick, scroll: next"
    onClicked: Store.toggleOn("theme", QsWindow.window ? QsWindow.window.screen : null)
    onScrolled: delta => Quickshell.execDetached(["qs", "-c", "torus", "ipc", "call", "torus", delta > 0 ? "wallpaperNext" : "wallpaperPrev"])
}
