import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    icon: "󰮯"
    tip: (Updates.count > 0 ? Updates.count + " updates available" : "Up to date") + (Updates.unread > 0 ? "\nArch news to read first" : "") + "\nClick: details, right click: check again"
    iconColor: Updates.unread > 0 ? Theme.peach : (Updates.count > 0 ? Theme.green : Theme.overlay)
    label: Updates.count > 0 ? Updates.count : ""
    onClicked: Store.toggleOn("updates", QsWindow.window ? QsWindow.window.screen : null)
    onRightClicked: Updates.check()
}
