import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    available: Backlight.available
    icon: "󰃟"
    tip: "Brightness, scroll to change"
    label: Backlight.percent + "%"
    onScrolled: delta => Backlight.adjust(delta * 5)
}
