import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import qs

PopupWindow {
    id: root

    required property Item anchorItem
    property var root_menu: null
    property var stack: []
    signal dismissed

    // one opener per level: moving a single opener to a submenu releases the parent, and the submenu's items with it
    readonly property var openers: [level0, level1, level2, level3]
    readonly property var current: openers[Math.min(stack.length, openers.length - 1)]

    anchor.item: anchorItem
    anchor.rect: Qt.rect(0, 0, anchorItem.width, anchorItem.height + 10)
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    implicitWidth: 260
    implicitHeight: Math.min(560, list.contentHeight + 16 + (stack.length > 0 ? 34 : 0))
    color: "transparent"
    visible: true

    HyprlandFocusGrab {
        active: root.visible
        windows: [root]
        onCleared: root.dismissed()
    }

    QsMenuOpener { id: level0; menu: root.root_menu }
    QsMenuOpener { id: level1; menu: root.stack.length > 0 ? root.stack[0] : null }
    QsMenuOpener { id: level2; menu: root.stack.length > 1 ? root.stack[1] : null }
    QsMenuOpener { id: level3; menu: root.stack.length > 2 ? root.stack[2] : null }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Qt.alpha(Theme.mantle, 0.96)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.35)
        focus: true
        Keys.onEscapePressed: root.dismissed()

        opacity: 0
        scale: 0.96
        Component.onCompleted: { opacity = 1; scale = 1; forceActiveFocus() }
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: Theme.sp1

            Rectangle {
                visible: root.stack.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                radius: Theme.rSm
                color: backHover.hovered ? Theme.surface0 : "transparent"
                Text { anchors.verticalCenter: parent.verticalCenter; x: 10; text: "󰁍  back"; color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd }
                HoverHandler { id: backHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.stack = root.stack.slice(0, -1) }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                interactive: contentHeight > height
                model: root.current.children
                delegate: Item {
                    id: row
                    required property var modelData
                    width: ListView.view.width
                    height: modelData.isSeparator ? 9 : 32

                    Rectangle {
                        visible: row.modelData.isSeparator
                        anchors.centerIn: parent
                        width: parent.width - 16
                        height: 1
                        color: Theme.surface1
                    }

                    Rectangle {
                        visible: !row.modelData.isSeparator
                        anchors.fill: parent
                        radius: Theme.rSm
                        color: rowHover.hovered && row.modelData.enabled ? Qt.alpha(Theme.accent, 0.18) : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: Theme.sp4
                            Text {
                                visible: row.modelData.buttonType !== 0
                                text: row.modelData.checkState === Qt.Checked ? (row.modelData.buttonType === 2 ? "󰐾" : "󰄵") : (row.modelData.buttonType === 2 ? "󰄯" : "󰄱")
                                color: Theme.accent
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fsBase
                            }
                            IconImage {
                                visible: row.modelData.icon !== ""
                                implicitSize: 16
                                source: row.modelData.icon
                            }
                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.text.replace(/_(.)/g, "$1")
                                color: row.modelData.enabled ? Theme.text : Theme.overlay
                                font.family: Theme.fontUi
                                font.pixelSize: Theme.fsMd
                                elide: Text.ElideRight
                            }
                            Text {
                                visible: row.modelData.hasChildren
                                text: "󰅂"
                                color: Theme.subtext
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fsMd
                            }
                        }

                        HoverHandler { id: rowHover; cursorShape: row.modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
                        TapHandler {
                            enabled: row.modelData.enabled
                            onTapped: {
                                if (row.modelData.hasChildren && root.stack.length < root.openers.length - 1) {
                                    root.stack = root.stack.concat([row.modelData])
                                } else {
                                    row.modelData.triggered()
                                    root.dismissed()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
