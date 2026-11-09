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
    visible: Store.isOpen("updates")
    onVisibleChanged: if (visible) {
        Updates.check()
        Updates.fetchNews()
    }
    anchors {
        top: true
        right: true
    }
    margins {
        top: Store.barGap
        right: 10
    }
    implicitWidth: 420
    implicitHeight: Math.min(680, body.implicitHeight + 32)
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "torus-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    Rectangle {
        PanelMotion {
            target: parent
            shown: root.visible
        }
        anchors.fill: parent
        radius: 18
        color: Qt.alpha(Theme.base, Theme.glassCard)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.35)
        clip: true
        focus: true
        Keys.onEscapePressed: Store.setOpen("updates", false)

        Flickable {
            anchors.fill: parent
            anchors.margins: 16
            contentHeight: body.implicitHeight
            clip: true

            ColumnLayout {
                id: body
                width: parent.width
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text { text: "󰮯"; color: Updates.count > 0 ? Theme.green : Theme.accent; font.family: Theme.fontMono; font.pixelSize: 18 }
                    Text {
                        Layout.fillWidth: true
                        text: Updates.checking ? "checking…" : (Updates.count > 0 ? Updates.count + (Updates.count === 1 ? " update" : " updates") : "everything is up to date")
                        color: Theme.text
                        font.family: Theme.fontUi
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }
                    Rectangle {
                        visible: Updates.count > 0
                        width: upText.implicitWidth + 24
                        height: 28
                        radius: 14
                        color: upHover.hovered ? Theme.green : Theme.accent
                        Text { id: upText; anchors.centerIn: parent; text: "Update now"; color: Theme.crust; font.family: Theme.fontUi; font.pixelSize: 12; font.weight: Font.DemiBold }
                        HoverHandler { id: upHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: { Store.setOpen("updates", false); Updates.update() } }
                    }
                }

                Rectangle {
                    visible: Updates.unread > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: warn.implicitHeight + 16
                    radius: 10
                    color: Qt.alpha(Theme.peach, 0.15)
                    border.width: 1
                    border.color: Qt.alpha(Theme.peach, 0.5)
                    Text {
                        id: warn
                        anchors.fill: parent
                        anchors.margins: 8
                        wrapMode: Text.WordWrap
                        text: "Arch posted news since your last full upgrade. Read it before updating."
                        color: Theme.peach
                        font.family: Theme.fontUi
                        font.pixelSize: 12
                    }
                }

                Repeater {
                    model: Updates.packages.slice(0, 40)
                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 8
                        Rectangle {
                            visible: modelData.source === "aur"
                            width: 30
                            height: 16
                            radius: 8
                            color: Theme.surface1
                            Text { anchors.centerIn: parent; text: "AUR"; color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: 9 }
                        }
                        Text { text: modelData.name; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
                        Text { text: modelData.from + "  →  " + modelData.to; color: Theme.subtext; font.family: Theme.fontMono; font.pixelSize: 10; elide: Text.ElideLeft; Layout.maximumWidth: 230 }
                    }
                }

                Text {
                    visible: Updates.packages.length > 40
                    text: "and " + (Updates.packages.length - 40) + " more"
                    color: Theme.overlay
                    font.family: Theme.fontUi
                    font.pixelSize: 11
                }

                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.surface1; Layout.topMargin: 4; Layout.bottomMargin: 4 }

                Text { text: "Arch news"; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: 11; font.letterSpacing: 1.2; font.capitalization: Font.AllUppercase }

                Repeater {
                    model: Updates.news
                    Rectangle {
                        id: item
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: newsCol.implicitHeight + 12
                        radius: 10
                        color: newsHover.hovered ? Theme.surface0 : "transparent"
                        RowLayout {
                            id: newsCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8
                            Rectangle { width: 7; height: 7; radius: 4; color: item.modelData.state === "new" ? Theme.peach : "transparent" }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text { Layout.fillWidth: true; text: item.modelData.title; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: 12; wrapMode: Text.WordWrap }
                                Text { text: item.modelData.date; color: Theme.overlay; font.family: Theme.fontMono; font.pixelSize: 10 }
                            }
                        }
                        HoverHandler { id: newsHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: Quickshell.execDetached(["xdg-open", item.modelData.link]) }
                    }
                }
            }
        }
    }
}
