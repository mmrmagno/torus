import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    icon: "󰔏"
    iconColor: SysStats.cpuTemp >= 80 ? Theme.red : Theme.sapphire
    widest: "100°C"
    label: SysStats.cpuTemp >= 0 ? SysStats.cpuTemp + "°C" : "--"
    card: Component { CpuCard {} }
}
