import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    property bool showTemp: false
    icon: "󰢮"
    label: showTemp ? (SysStats.gpuTemp >= 0 ? SysStats.gpuTemp + "°C" : "--") : (SysStats.gpuBusy >= 0 ? SysStats.gpuBusy + "%" : "--")
    onClicked: showTemp = !showTemp
}
