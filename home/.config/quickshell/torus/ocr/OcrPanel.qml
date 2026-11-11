import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.components

PanelWindow {
    id: root

    readonly property string file: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/torus-ocr.txt"
    property string copied: ""
    readonly property var lines: source.text().split("\n")

    function copy(text, what) {
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", text])
        copied = what
        copiedReset.restart()
    }

    screen: Store.screenFor("ocr")
    visible: Store.isOpen("ocr") || motion.leaving
    onVisibleChanged: if (visible) { copied = "all"; source.reload() }
    anchors.top: true
    margins.top: Store.barGap
    implicitWidth: Math.min(640, (screen ? screen.width : 800) - 40)
    implicitHeight: Math.min((screen ? screen.height : 800) * 0.7, body.implicitHeight + 32)
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "torus-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Store.isOpen("ocr") && !Store.moving ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    FileView { id: source; path: root.file; blockLoading: true; printErrors: false }
    Timer { id: copiedReset; interval: 2500; onTriggered: root.copied = "" }

    HyprlandFocusGrab {
        active: Store.isOpen("ocr")
        windows: [root]
        onCleared: Store.setOpen("ocr", false)
    }

    Rectangle {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Store.setOpen("ocr", false)
        Keys.onReturnPressed: { root.copy(source.text().trim(), "all"); Store.setOpen("ocr", false) }
        PanelMotion { id: motion; target: parent; shown: Store.isOpen("ocr") && !Store.moving }
        radius: Theme.rPanel
        color: Qt.alpha(Theme.base, Theme.glassCard)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.35)
        clip: true

        ColumnLayout {
            id: body
            anchors.fill: parent
            anchors.margins: 16
            spacing: Theme.sp5

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sp4
                Text { text: "󰊄"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 22 }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text { Layout.fillWidth: true; elide: Text.ElideRight; text: "Text from the picture"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsTitle; font.weight: Font.DemiBold }
                    Text {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: root.copied === "all" ? "All of it is on the clipboard. Click a line to copy only that one."
                            : root.copied === "line" ? "That line is on the clipboard." : "Click a line to copy it."
                        color: root.copied ? Theme.green : Theme.overlay
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsSm
                    }
                }
                PanelButton { label: "Copy all"; icon: "󰆏"; implicitHeight: 30; onClicked: root.copy(source.text().trim(), "all") }
                PanelButton {
                    label: "Edit"
                    icon: "󰏫"
                    implicitHeight: 30
                    onClicked: {
                        Quickshell.execDetached(["kitty", "-e", "nvim", root.file])
                        Store.setOpen("ocr", false)
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: flick.height + 16
                radius: Theme.rCard
                color: Qt.alpha(Theme.surface0, 0.55)
                border.width: 1
                border.color: Qt.alpha(Theme.surface1, 0.6)

                Flickable {
                    id: flick
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 8
                    height: Math.min(contentHeight, (root.screen ? root.screen.height : 800) * 0.7 - 116)
                    contentHeight: linesCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: linesCol
                        width: parent.width
                        spacing: 2
                        Repeater {
                            model: root.lines
                            Rectangle {
                                id: line
                                required property string modelData
                                readonly property bool blank: modelData.trim() === ""
                                width: linesCol.width
                                height: blank ? 10 : lineText.implicitHeight + 8
                                radius: Theme.rSm
                                color: !blank && lineHover.hovered ? Qt.alpha(Theme.accent, 0.16) : "transparent"
                                Text {
                                    id: lineText
                                    visible: !line.blank
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    text: line.modelData
                                    color: Theme.text
                                    font.family: Theme.fontUi
                                    font.pixelSize: Theme.fsMd
                                    wrapMode: Text.Wrap
                                }
                                HoverHandler { id: lineHover; enabled: !line.blank; cursorShape: Qt.PointingHandCursor }
                                TapHandler { enabled: !line.blank; onTapped: root.copy(line.modelData.trim(), "line") }
                            }
                        }
                    }
                }
            }
        }
    }
}
