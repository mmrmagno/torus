import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    available: Backlight.available
    icon: "󰃟"
    label: Backlight.percent + "%"
    onScrolled: delta => Backlight.adjust(delta * 5)
}
