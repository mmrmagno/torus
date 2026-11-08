import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

import Quickshell.Services.UPower

Chip {
    readonly property var dev: UPower.displayDevice
    available: dev && dev.isLaptopBattery
    icon: dev && dev.state === UPowerDeviceState.Charging ? "󰂄" : "󰁹"
    tip: dev ? "Battery " + Math.round(dev.percentage * 100) + "%" : ""
    iconColor: dev && dev.percentage < 0.2 ? Theme.red : Theme.green
    label: dev ? Math.round(dev.percentage * 100) + "%" : ""
}
