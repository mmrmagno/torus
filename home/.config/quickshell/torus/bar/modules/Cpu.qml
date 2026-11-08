import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    icon: "󰍛"
    label: Math.round(SysStats.cpu) + "%"
}
