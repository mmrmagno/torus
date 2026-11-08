import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    icon: "󰾆"
    label: SysStats.memUsed.toFixed(1) + "G"
}
