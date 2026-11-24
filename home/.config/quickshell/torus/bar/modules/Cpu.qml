import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    icon: "󰍛"
    widest: "100%"
    label: Math.round(SysStats.cpu) + "%"
    card: Component { CpuCard {} }
}
