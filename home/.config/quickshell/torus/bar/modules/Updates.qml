import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    icon: "󰮯"
    iconColor: Updates.count > 0 ? Theme.green : Theme.overlay
    label: Updates.count > 0 ? Updates.count : ""
    onClicked: Quickshell.execDetached(["kitty", "--title", "torus-update", "-e", "sh", "-c", "yay -Syu; echo; read -n1 -p 'done, press a key'"])
    onRightClicked: Updates.check()
}
