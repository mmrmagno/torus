import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

PanelWindow {
    id: root

    screen: Store.focusedScreen
    visible: Store.isOpen("center")
    anchors {
        top: true
        right: true
        bottom: true
    }
    margins {
        top: Store.barGap
        right: 10
        bottom: 10
    }
    implicitWidth: 420
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "torus-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Qt.alpha(Theme.base, Theme.glass)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.35)
        focus: true
        Keys.onEscapePressed: Store.setOpen("center", false)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "Notifications"
                    color: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }
                PanelButton { icon: Store.dnd ? "󰂛" : "󰂚"; active: Store.dnd; onClicked: Store.dnd = !Store.dnd }
                PanelButton { icon: "󰎟"; onClicked: Notifs.clearAll() }
            }

            MediaCard { Layout.fillWidth: true }

            Flow {
                Layout.fillWidth: true
                spacing: 6
                PanelButton { icon: "󰖩"; label: "Network"; onClicked: Quickshell.execDetached(["nm-connection-editor"]) }
                PanelButton { icon: "󰂯"; label: "Bluetooth"; onClicked: Quickshell.execDetached(["blueman-manager"]) }
                PanelButton { icon: "󰖔"; label: "Night light"; onClicked: Quickshell.execDetached(["sh", "-c", "hyprctl hyprsunset temperature 5500"]) }
                PanelButton { icon: "󰐥"; label: "Session"; onClicked: { Store.setOpen("center", false); Store.setOpen("logout", true) } }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 8
                model: ScriptModel { values: Notifs.groups.map(g => g.app) }
                delegate: NotifGroup {
                    required property var modelData
                    app: modelData
                    width: ListView.view.width
                }
                Text {
                    anchors.centerIn: list
                    visible: list.count === 0
                    text: "󰂜  all caught up"
                    color: Theme.overlay
                    font.family: Theme.fontMono
                    font.pixelSize: 14
                }
            }
        }
    }
}
