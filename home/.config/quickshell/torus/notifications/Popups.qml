import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services

PanelWindow {
    id: root

    screen: Store.focusedScreen
    anchors {
        top: true
        right: true
    }
    margins {
        top: Store.barGap
        right: 10
    }
    implicitWidth: 400
    implicitHeight: Math.max(1, column.implicitHeight)
    exclusiveZone: 0
    color: "transparent"
    visible: Notifs.popups.length > 0 && !Store.isOpen("center")
    WlrLayershell.namespace: "torus-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    Column {
        id: column
        width: parent.width
        spacing: 8

        Repeater {
            model: ScriptModel { values: Notifs.popups }
            NotifCard {
                required property var modelData
                notif: modelData
                popup: true
                width: column.width
                onDone: Notifs.dismissPopup(modelData)
            }
        }
    }
}
