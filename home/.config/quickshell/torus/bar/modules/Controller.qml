import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs
import qs.components

Chip {
    readonly property var pads: UPower.devices.values.filter(d => d.type === UPowerDeviceType.GamingInput && d.isPresent)
    readonly property var low: pads.length > 0 ? pads.reduce((a, b) => a.percentage <= b.percentage ? a : b) : null
    readonly property int pct: low ? Math.round(low.percentage * 100) : -1
    readonly property bool shown: pads.length > 0

    icon: "󰊴"
    iconColor: pct >= 0 && pct < 20 ? Theme.red : Theme.accent
    label: pct >= 0 ? pct + "%" : ""
    tip: pads.map(d => (d.model || "Controller") + ": " + Math.round(d.percentage * 100) + "%").join("\n")
}
