import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    property bool showTemp: false
    readonly property int heat: SysStats.gpuHotspot >= 0 ? SysStats.gpuHotspot : SysStats.gpuTemp
    readonly property string busy: SysStats.gpuBusy >= 0 ? SysStats.gpuBusy + "%" : "--"
    icon: "󰢮"
    iconColor: !Store.gamemode || heat < 85 ? Theme.accent : heat >= 95 ? Theme.red : Theme.peach
    label: (Play.buffering ? "● REC  " : "") + (Store.gamemode ? busy + " · " + (heat >= 0 ? heat + "°" : "--") : (showTemp ? (SysStats.gpuTemp >= 0 ? SysStats.gpuTemp + "°C" : "--") : busy))
    tip: Play.buffering ? "Replay buffer running for " + (Play.session.name || "the game") + ", SUPER+ALT+R saves the last " + (Play.session.replay_secs || 60) + " s" : ""
    onClicked: showTemp = !showTemp
    card: Component { GpuCard {} }
}
