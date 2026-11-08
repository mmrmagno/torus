import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    property bool warm: false
    icon: warm ? "󰖔" : "󰖨"
    iconColor: warm ? Theme.peach : Theme.overlay
    onClicked: {
        warm = !warm
        Quickshell.execDetached(["hyprctl", "hyprsunset", warm ? "temperature 5500" : "identity"])
    }
}
