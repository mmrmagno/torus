import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.components
import qs.services

PanelWindow {
    id: root

    screen: Store.screenFor("updates")
    visible: Store.isOpen("updates") || motion.leaving
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
    implicitHeight: Math.floor(Math.min(680, Store.panelRoom(screen, 16)))
    mask: Region { item: updFrame }
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "torus-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Store.isOpen("updates") && !Store.moving ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        active: Store.isOpen("updates") && root.backingWindowVisible
        windows: [root]
        onCleared: Store.setOpen("updates", false)
    }

    Rectangle {
        id: updFrame
        focus: true
        Keys.onEscapePressed: Store.setOpen("updates", false)
        PanelMotion {
            id: motion
            target: updFrame
            shown: Store.isOpen("updates") && !Store.moving
        }
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.min(body.implicitHeight + 32, root.implicitHeight)
        Behavior on height { enabled: root.visible; NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } }
        transformOrigin: Item.TopRight
        radius: Theme.rPanel
        color: Qt.alpha(Theme.base, Theme.glassCard)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.35)
        clip: true

        Flickable {
            anchors.fill: parent
            anchors.margins: 16
            contentHeight: body.implicitHeight
            clip: true

            ColumnLayout {
                id: body
                width: parent.width
                spacing: Theme.sp5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.sp4
                    Text { text: "󰮯"; color: Updates.count > 0 ? Theme.green : Theme.accent; font.family: Theme.fontMono; font.pixelSize: Theme.fsTitle }
                    Text {
                        Layout.fillWidth: true
                        text: Updates.checking ? "Checking for updates…" : (Updates.count > 0 ? Updates.count + (Updates.count === 1 ? " update" : " updates") : "Everything is up to date")
                        color: Theme.text
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsLg
                        font.weight: Font.DemiBold
                    }
                    Rectangle {
                        visible: Updates.count > 0
                        width: upText.implicitWidth + 24
                        height: 28
                        radius: 14
                        color: upHover.hovered ? Theme.green : Theme.accent
                        Text { id: upText; anchors.centerIn: parent; text: "Update now"; color: Theme.crust; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd; font.weight: Font.DemiBold }
                        HoverHandler { id: upHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: { Store.setOpen("updates", false); Updates.update() } }
                    }
                }

                Rectangle {
                    visible: Updates.unread > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: warn.implicitHeight + 16
                    radius: Theme.radius
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
                        font.pixelSize: Theme.fsMd
                    }
                }

                Repeater {
                    model: Updates.packages.slice(0, 40)
                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Theme.sp4
                        Rectangle {
                            visible: modelData.source === "aur"
                            width: 30
                            height: 16
                            radius: Theme.rSm
                            color: Theme.surface1
                            Text { anchors.centerIn: parent; text: "AUR"; color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: Theme.fsXs }
                        }
                        Text { text: modelData.name; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fsMd; Layout.fillWidth: true; elide: Text.ElideRight }
                        Text { text: modelData.from + "  →  " + modelData.to; color: Theme.subtext; font.family: Theme.fontMono; font.pixelSize: Theme.fsXs; elide: Text.ElideLeft; Layout.maximumWidth: 230 }
                    }
                }

                Text {
                    visible: Updates.packages.length > 40
                    text: "and " + (Updates.packages.length - 40) + " more"
                    color: Theme.overlay
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsSm
                }

                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.surface1; Layout.topMargin: 4; Layout.bottomMargin: 4 }

                RowLayout {
                    Layout.fillWidth: true
                    visible: Updates.torusInstalled !== null
                    spacing: Theme.sp4
                    Text { Layout.fillWidth: true; text: "torus"; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; font.letterSpacing: 1.2; font.capitalization: Font.AllUppercase }
                    Text {
                        visible: Updates.torus.length === 0
                        text: Updates.torusInstalled ? "up to date at " + Updates.torusInstalled.hash : ""
                        color: Theme.overlay
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fsXs
                    }
                    PanelButton {
                        visible: Updates.torus.length > 0
                        icon: "󰚰"
                        label: "Update torus"
                        implicitHeight: 28
                        onClicked: {
                            Store.setOpen("updates", false)
                            Updates.updateTorus()
                        }
                    }
                }

                Repeater {
                    model: Updates.torus.slice(0, 12)
                    RowLayout {
                        id: crow
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Theme.sp4
                        Text { text: crow.modelData.hash; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: Theme.fsXs }
                        Text { Layout.fillWidth: true; text: crow.modelData.subject; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd; elide: Text.ElideRight }
                        Text { text: crow.modelData.date; color: Theme.overlay; font.family: Theme.fontMono; font.pixelSize: Theme.fsXs }
                    }
                }

                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.surface1; Layout.topMargin: 4; Layout.bottomMargin: 4; visible: Updates.torusInstalled !== null }

                Text { text: "Arch news"; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; font.letterSpacing: 1.2; font.capitalization: Font.AllUppercase }

                Repeater {
                    model: Updates.news
                    Rectangle {
                        id: item
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: newsCol.implicitHeight + 12
                        radius: Theme.radius
                        color: newsHover.hovered ? Theme.surface0 : "transparent"
                        RowLayout {
                            id: newsCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: Theme.sp4
                            Rectangle { width: 7; height: 7; radius: 4; color: item.modelData.state === "new" ? Theme.peach : "transparent" }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text { Layout.fillWidth: true; text: item.modelData.title; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd; wrapMode: Text.WordWrap }
                                Text { text: item.modelData.date; color: Theme.overlay; font.family: Theme.fontMono; font.pixelSize: Theme.fsXs }
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
