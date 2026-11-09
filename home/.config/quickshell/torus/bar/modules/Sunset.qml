import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    icon: NightLight.on ? "󰖔" : "󰖨"
    iconColor: NightLight.on ? Theme.peach : Theme.overlay
    tip: (NightLight.on ? "Night light on, " + NightLight.temperature + " K" : "Night light off") + (NightLight.auto ? "\nSchedule: on at " + NightLight.sunset + ", off at " + NightLight.sunrise : "\nSchedule off") + "\nClick: toggle, right click: " + (NightLight.auto ? "stop" : "start") + " the schedule"
    onClicked: NightLight.toggle()
    onRightClicked: NightLight.setAuto(!NightLight.auto)
}
