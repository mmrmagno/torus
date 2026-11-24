import QtQuick
import Quickshell
import qs
import qs.components
import qs.services

import Quickshell.Hyprland
import Quickshell.Widgets

Row {
    id: root
    property bool available: true
    function hits() {
        return children.filter(c => c.area).map(c => [c.area.width, c.area.height])
    }
    readonly property bool shown: windows.count > 0
    property var monitor: QsWindow.window ? Hyprland.monitorFor(QsWindow.window.screen) : null
    spacing: 0

    Repeater {
        id: windows
        model: Hyprland.toplevels.values.filter(t => t.workspace && root.monitor && !Pins.isPin(t) && t.workspace === root.monitor.activeWorkspace)

        Item {
            id: task
            required property var modelData
            readonly property Item area: taskArea
            readonly property string appId: modelData.wayland && modelData.wayland.appId ? modelData.wayland.appId : (modelData.lastIpcObject ? modelData.lastIpcObject.class || "" : "")
            readonly property var entry: DesktopEntries.applications.values.length >= 0 ? DesktopEntries.heuristicLookup(appId) : null
            implicitWidth: 28
            implicitHeight: 16
            anchors.verticalCenter: parent.verticalCenter

            IconImage {
                id: taskIcon
                anchors.centerIn: parent
                implicitSize: 16
                source: Quickshell.iconPath(task.entry ? task.entry.icon : "", "application-x-executable")
                opacity: task.modelData.activated || taskHover.hovered ? 1 : 0.55
                Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
            }

            HoverHandler { id: taskHover }
            Press { target: taskIcon; down: taskArea.pressed }

            MouseArea {
                id: taskArea
                anchors.centerIn: parent
                width: task.width
                height: Store.barHeight
                cursorShape: Qt.PointingHandCursor
                onClicked: Store.focusWindow(task.modelData)
            }
        }
    }
}
