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
    implicitHeight: Store.panelRoom(screen, 16)
    mask: Region { regions: cardRegions.instances }
    exclusiveZone: 0
    color: "transparent"
    visible: Notifs.popups.length > 0 && !Store.isOpen("center")
    WlrLayershell.namespace: "torus-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Variants {
        id: cardRegions
        model: column.children
        Region {
            required property Item modelData
            item: modelData
        }
    }

    Column {
        id: column
        width: parent.width
        spacing: Theme.sp4
        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durMed; easing.type: Easing.OutCubic }
                NumberAnimation { property: "x"; from: 48; to: 0; duration: Theme.durSlow; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
            }
        }
        move: Transition {
            NumberAnimation { property: "y"; duration: Theme.durMed; easing.type: Easing.OutCubic }
        }

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
