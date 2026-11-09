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
    visible: Store.isOpen("clip")
    implicitWidth: 560
    implicitHeight: 540
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "torus-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: if (visible) {
        search.text = ""
        list.currentIndex = 0
        search.forceActiveFocus()
    }

    Rectangle {
        PanelMotion {
            target: parent
            shown: root.visible
        }
        anchors.fill: parent
        radius: 16
        color: Qt.alpha(Theme.base, Theme.glass)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.35)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: 12
                color: Theme.surface0
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10
                    Text {
                        text: "󰅌"
                        color: Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: 16
                    }
                    TextInput {
                        id: search
                        Layout.fillWidth: true
                        color: Theme.text
                        font.family: Theme.fontUi
                        font.pixelSize: 14
                        onTextChanged: {
                            Clip.filter = text
                            list.currentIndex = 0
                        }
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape)
                                Store.setOpen("clip", false)
                            else if (event.key === Qt.Key_Down)
                                list.incrementCurrentIndex()
                            else if (event.key === Qt.Key_Up)
                                list.decrementCurrentIndex()
                            else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && Clip.shown.length > 0)
                                Clip.copy(Clip.shown[list.currentIndex])
                            else if (event.key === Qt.Key_Delete && Clip.shown.length > 0)
                                Clip.remove(Clip.shown[list.currentIndex])
                            else if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier) && Clip.shown.length > 0)
                                Clip.togglePin(Clip.shown[list.currentIndex])
                            else
                                return
                            event.accepted = true
                        }
                        Text {
                            visible: parent.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: "filter clipboard · enter copies · ctrl+p pins · del removes"
                            color: Theme.overlay
                            font: parent.font
                        }
                    }
                    Text {
                        text: Clip.shown.length
                        color: Theme.overlay
                        font.family: Theme.fontMono
                        font.pixelSize: 12
                    }
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: Clip.shown
                highlightMoveDuration: 120
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: modelData.image ? 84 : 44
                    radius: 10
                    color: ListView.isCurrentItem ? Qt.alpha(Theme.accent, 0.18) : (hover.hovered ? Theme.surface0 : "transparent")
                    border.width: ListView.isCurrentItem ? 1 : 0
                    border.color: Qt.alpha(Theme.accent, 0.5)

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        anchors.leftMargin: 12
                        spacing: 12
                        Text {
                            visible: row.modelData.pinned === true
                            text: "󰐃"
                            color: Theme.peach
                            font.family: Theme.fontMono
                            font.pixelSize: 14
                        }
                        Image {
                            visible: row.modelData.image !== ""
                            Layout.preferredWidth: 110
                            Layout.preferredHeight: 68
                            source: row.modelData.image
                            sourceSize.width: 220
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: false
                        }
                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.text
                            color: row.modelData.image ? Theme.subtext : Theme.text
                            font.family: row.modelData.image ? Theme.fontUi : Theme.fontMono
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.WrapAnywhere
                            textFormat: Text.PlainText
                        }
                        Text {
                            text: "󰆴"
                            color: delHover.hovered ? Theme.red : Theme.overlay
                            font.family: Theme.fontMono
                            font.pixelSize: 14
                            MouseArea {
                                id: delHover
                                readonly property bool hovered: containsMouse
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                onClicked: Clip.remove(row.modelData)
                            }
                        }
                    }
                    MouseArea {
                        id: hover
                        readonly property bool hovered: containsMouse
                        anchors.fill: parent
                        z: -1
                        hoverEnabled: true
                        onClicked: Clip.copy(row.modelData)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    text: Clip.entries.length === 0 ? "clipboard history is empty" : "no match"
                    color: Theme.overlay
                    font.family: Theme.fontMono
                    font.pixelSize: 13
                }
            }
        }
    }
}
