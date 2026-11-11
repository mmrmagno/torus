import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

PanelWindow {
    id: root

    screen: Store.screenFor("clip")
    visible: Store.isOpen("clip") || motion.leaving
    implicitWidth: 560
    implicitHeight: 540
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "torus-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Store.isOpen("clip") ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property int keepIndex: -1
    property string keep: ""

    function removeAt(i) {
        if (i < 0 || i >= Clip.shown.length)
            return
        keepIndex = i
        keep = ""
        Clip.remove(Clip.shown[i])
    }

    Connections {
        target: Clip
        function onShownChanged() {
            if (root.keep !== "") {
                const i = Clip.shown.findIndex(e => e.text === root.keep)
                root.keep = ""
                if (i >= 0)
                    Qt.callLater(() => { list.currentIndex = i; list.positionViewAtIndex(i, ListView.Contain) })
            } else if (root.keepIndex >= 0) {
                const i = Math.min(root.keepIndex, Clip.shown.length - 1)
                root.keepIndex = -1
                Qt.callLater(() => { list.currentIndex = i; list.positionViewAtIndex(i, ListView.Contain) })
            }
        }
    }

    onVisibleChanged: if (visible) {
        Clip.kindFilter = "all"
        search.text = ""
        list.currentIndex = 0
        search.forceActiveFocus()
    }

    Rectangle {
        PanelMotion {
            id: motion
            target: parent
            shown: Store.isOpen("clip")
        }
        anchors.fill: parent
        radius: 16
        color: Qt.alpha(Theme.base, Theme.glass)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.35)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: Theme.sp5

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: Theme.rCard
                color: Theme.surface0
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: Theme.sp5
                    Text {
                        text: "󰅌"
                        color: Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fsXl
                    }
                    TextInput {
                        id: search
                        Layout.fillWidth: true
                        color: Theme.text
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsLg
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
                                root.removeAt(list.currentIndex)
                            else if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier) && Clip.shown.length > 0) {
                                root.keep = Clip.shown[list.currentIndex].text || ""
                                Clip.togglePin(Clip.shown[list.currentIndex])
                            }
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
                        font.pixelSize: Theme.fsMd
                    }
                }
            }

            Row {
                Layout.fillWidth: true
                spacing: Theme.sp3
                Repeater {
                    model: [["all", "All", "󰅌"], ["text", "Text", "󰦨"], ["link", "Links", "󰌹"], ["image", "Images", "󰋩"], ["color", "Colors", "󰏘"], ["code", "Code", "󰅩"]]
                    Rectangle {
                        required property var modelData
                        readonly property bool on: Clip.kindFilter === modelData[0]
                        width: chipRow.implicitWidth + 18
                        height: 26
                        radius: 13
                        color: on ? Theme.accent : (chipHover.hovered ? Theme.surface1 : Theme.surface0)
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }
                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 5
                            Text { text: parent.parent.modelData[2]; color: parent.parent.on ? Theme.crust : Theme.accent; font.family: Theme.fontMono; font.pixelSize: Theme.fsMd; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: parent.parent.modelData[1]; color: parent.parent.on ? Theme.crust : Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; anchors.verticalCenter: parent.verticalCenter }
                        }
                        HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: { Clip.kindFilter = parent.modelData[0]; list.currentIndex = 0 } }
                    }
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Theme.sp3
                model: Clip.shown
                highlightMoveDuration: 120
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    readonly property string kind: modelData.kind || "text"
                    height: modelData.image ? 96 : (kind === "code" ? 58 : 46)
                    radius: Theme.radius
                    color: ListView.isCurrentItem ? Qt.alpha(Theme.accent, 0.18) : (hover.hovered ? Theme.surface0 : "transparent")
                    border.width: ListView.isCurrentItem ? 1 : 0
                    border.color: Qt.alpha(Theme.accent, 0.5)

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        anchors.leftMargin: 12
                        spacing: Theme.sp6
                        Text {
                            visible: row.modelData.pinned === true
                            text: "󰐃"
                            color: Theme.peach
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fsLg
                        }
                        Rectangle {
                            visible: row.kind === "color"
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 8
                            color: row.modelData.color || "transparent"
                            border.width: 1
                            border.color: Qt.alpha(Theme.text, 0.2)
                        }
                        Text {
                            visible: row.kind !== "color" && row.kind !== "image"
                            Layout.preferredWidth: 28
                            horizontalAlignment: Text.AlignHCenter
                            text: ({ link: "󰌹", email: "󰇮", path: "󰉋", code: "󰅩", text: "󰦨" })[row.kind] || "󰦨"
                            color: row.kind === "link" ? Theme.blue : (row.kind === "code" ? Theme.green : (row.kind === "path" ? Theme.yellow : Theme.overlay))
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fsXl
                        }
                        Image {
                            visible: row.modelData.image !== ""
                            Layout.preferredWidth: 128
                            Layout.preferredHeight: 80
                            source: row.modelData.image
                            sourceSize.width: 220
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: false
                        }
                        Text {
                            visible: row.kind === "link"
                            Layout.fillWidth: true
                            text: "<b>" + (row.modelData.host || "") + "</b><font color=\"" + Theme.overlay + "\">" + (row.modelData.rest || "").replace(/&/g, "&amp;").replace(/</g, "&lt;") + "</font>"
                            textFormat: Text.StyledText
                            color: Theme.text
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fsMd
                            elide: Text.ElideRight
                        }
                        Rectangle {
                            visible: row.kind === "code"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            radius: Theme.rSm
                            color: Qt.alpha(Theme.crust, 0.7)
                            border.width: 1
                            border.color: Qt.alpha(Theme.green, 0.25)
                            Text {
                                anchors.fill: parent
                                anchors.margins: 6
                                text: row.modelData.text
                                color: Theme.text
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fsSm
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.WrapAnywhere
                                textFormat: Text.PlainText
                            }
                        }
                        Text {
                            visible: row.kind !== "link" && row.kind !== "code"
                            Layout.fillWidth: true
                            text: row.kind === "color" ? row.modelData.text.trim() : row.modelData.text
                            color: row.modelData.image ? Theme.subtext : Theme.text
                            font.family: row.modelData.image || row.kind === "text" || row.kind === "email" ? Theme.fontUi : Theme.fontMono
                            font.pixelSize: Theme.fsMd
                            elide: row.kind === "path" ? Text.ElideMiddle : Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.WrapAnywhere
                            textFormat: Text.PlainText
                        }
                        Text {
                            text: "󰆴"
                            color: delHover.hovered ? Theme.red : Theme.overlay
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fsLg
                            MouseArea {
                                id: delHover
                                readonly property bool hovered: containsMouse
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                onClicked: root.removeAt(row.index)
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
                    font.pixelSize: Theme.fsBase
                }
            }
        }
    }
}
