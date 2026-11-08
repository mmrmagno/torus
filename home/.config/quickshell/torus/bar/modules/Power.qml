import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    icon: "󰐥"
    iconColor: Theme.red
    onClicked: Store.toggle("logout")
}
