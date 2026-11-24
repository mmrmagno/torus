import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    icon: "󰾆"
    widest: "00.0G"
    label: SysStats.memUsed.toFixed(1) + "G"
    card: Component { MemCard {} }
}
