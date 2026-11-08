import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    icon: "󰐥"
    tip: "Lock, log out, reboot, power off"
    iconColor: Theme.red
    onClicked: Store.toggle("logout")
}
