import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

import Quickshell.Services.Pipewire

Chip {
    readonly property int recording: Pipewire.nodes.values.filter(n => n.isStream && !n.isSink && n.audio).length
    readonly property bool shown: recording > 0
    icon: "󰍬"
    iconColor: Theme.red
    label: recording > 1 ? recording : ""
}
