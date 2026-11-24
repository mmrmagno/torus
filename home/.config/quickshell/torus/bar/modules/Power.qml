import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    id: chip

    icon: "󰐥"
    tip: "Lock, log out, reboot, power off"
    iconColor: Theme.red
    onClicked: Store.toggleFrom("logout", chip)
}
