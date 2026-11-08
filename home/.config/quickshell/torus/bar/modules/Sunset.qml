import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    icon: NightLight.on ? "󰖔" : "󰖨"
    iconColor: NightLight.on ? Theme.peach : Theme.overlay
    tip: NightLight.on ? "Night light on, " + NightLight.temperature + " K" : "Night light off"
    onClicked: NightLight.toggle()
}
