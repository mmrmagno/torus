import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import qs
import qs.components
import qs.services

PanelWindow {
    id: root

    function entryFor(cls) {
        DesktopEntries.applications
        return DesktopEntries.heuristicLookup(cls)
    }
    function nameFor(cls) {
        const e = entryFor(cls)
        return e && e.name ? e.name : cls
    }
    function reasonFor(v) {
        return v === "never" ? "games and system windows never reopen"
             : v === "skipped" ? "you turned this one off"
             : "no app launcher found for it"
    }
    function shortDir(d) {
        const home = Quickshell.env("HOME")
        return d && d.startsWith(home) ? "~" + d.slice(home.length) : (d || "~")
    }

    screen: Store.screenFor("session")
    visible: Store.isOpen("session") || motion.leaving
    onVisibleChanged: if (visible) Session.refresh()
    anchors {
        top: true
        right: true
    }
    margins {
        top: Store.barGap
        right: 10
    }
    implicitWidth: 440
    implicitHeight: Math.floor(Math.min(720, Store.panelRoom(screen, 16)))
    mask: Region { item: sessFrame }
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "torus-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Store.isOpen("session") && !Store.moving ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        active: Store.isOpen("session") && root.backingWindowVisible
        windows: [root]
        onCleared: Store.setOpen("session", false)
    }

    Rectangle {
        id: sessFrame
        focus: true
        Keys.onEscapePressed: Store.setOpen("session", false)
        PanelMotion {
            id: motion
            target: sessFrame
            shown: Store.isOpen("session") && !Store.moving
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
                    spacing: Theme.sp5
                    Rectangle {
                        width: 36
                        height: 36
                        radius: Theme.radius
                        color: Session.on ? Qt.alpha(Theme.accent, 0.18) : Theme.surface0
                        Text {
                            anchors.centerIn: parent
                            text: Session.on ? "󰑓" : "󰜺"
                            color: Session.on ? Theme.accent : Theme.overlay
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fsTitle
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text { text: "Session restore"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsLg; font.weight: Font.DemiBold }
                        Text {
                            text: Session.on ? "On: your windows reopen after a reboot" : "Off: nothing reopens after a reboot"
                            color: Session.on ? Theme.green : Theme.peach
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fsMd
                        }
                    }
                    Toggle {
                        checked: Session.on
                        onToggled: value => Session.setOn(value)
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: savedRow.implicitHeight + 16
                    radius: Theme.radius
                    color: Theme.surface0
                    RowLayout {
                        id: savedRow
                        anchors.fill: parent
                        anchors.margins: 8
                        anchors.leftMargin: 10
                        spacing: Theme.sp4
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: Session.saved > 0 ? "Saved " + Session.ago(Session.savedAt) + ", " + Session.saved + (Session.saved === 1 ? " window" : " windows") : "Nothing saved yet"
                                color: Theme.text
                                font.family: Theme.fontUi
                                font.pixelSize: Theme.fsMd
                            }
                            Text {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                text: "Saves by itself when windows open or close, and when you log out"
                                color: Theme.overlay
                                font.family: Theme.fontUi
                                font.pixelSize: Theme.fsXs
                            }
                        }
                        PanelButton { icon: "󰆓"; label: "Save"; implicitHeight: 28; onClicked: Session.saveNow() }
                        PanelButton { icon: "󰆴"; label: "Forget"; implicitHeight: 28; visible: Session.saved > 0; onClicked: Session.clear() }
                    }
                }

                Text {
                    text: "Comes back  ·  " + Session.keep.length
                    color: Theme.overlay
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsSm
                    font.letterSpacing: 1.2
                    font.capitalization: Font.AllUppercase
                    Layout.topMargin: 4
                }

                Text {
                    visible: Session.keep.length === 0
                    text: "No open windows would come back."
                    color: Theme.subtext
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsMd
                }

                Repeater {
                    model: Session.keep
                    delegate: WindowRow {
                        dim: !Session.on
                        actionLabel: "Don't restore"
                        onAction: Session.setSkipped(modelData.class, true)
                    }
                }

                Text {
                    visible: Session.lost.length > 0
                    text: "Won't come back  ·  " + Session.lost.length
                    color: Theme.overlay
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsSm
                    font.letterSpacing: 1.2
                    font.capitalization: Font.AllUppercase
                    Layout.topMargin: 6
                }

                Repeater {
                    model: Session.lost
                    delegate: WindowRow {
                        dim: true
                        note: root.reasonFor(modelData.verdict)
                        actionLabel: modelData.verdict === "skipped" ? "Restore it" : ""
                        onAction: Session.setSkipped(modelData.class, false)
                    }
                }

                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.surface1; Layout.topMargin: 6; Layout.bottomMargin: 2 }

                Text { text: "Good to know"; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; font.letterSpacing: 1.2; font.capitalization: Font.AllUppercase }

                Repeater {
                    model: [
                        ["󰏌", "Apps reopen fresh. Tabs and open files come back only if the app restores them itself (browsers do)."],
                        ["󰆍", "Terminals reopen in the same folder, without running commands or scrollback."],
                        ["󰕰", "Each window returns to its workspace. Size and position are not kept."],
                        ["󰜺", "Games, Steam titles and the scratchpad are never reopened."]
                    ]
                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Theme.sp4
                        Text { text: modelData[0]; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: Theme.fsBase; Layout.alignment: Qt.AlignTop }
                        Text { Layout.fillWidth: true; text: modelData[1]; wrapMode: Text.WordWrap; color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm }
                    }
                }
            }
        }
    }

    component WindowRow: Rectangle {
        id: row
        required property var modelData
        property bool dim: false
        property string note: ""
        property string actionLabel: ""
        signal action

        Layout.fillWidth: true
        Layout.preferredHeight: 40
        radius: Theme.radius
        color: rowHover.hovered ? Theme.surface0 : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: Theme.sp5
            opacity: row.dim ? 0.55 : 1
            IconImage {
                implicitSize: 22
                source: {
                    const e = root.entryFor(row.modelData.class)
                    return Quickshell.iconPath(e ? e.icon : row.modelData.class.toLowerCase(), "application-x-executable")
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: root.nameFor(row.modelData.class)
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsMd
                }
                Text {
                    Layout.fillWidth: true
                    text: row.note !== "" ? row.note : (row.modelData.class === "kitty" ? root.shortDir(row.modelData.dir) : "")
                    visible: text !== ""
                    elide: Text.ElideMiddle
                    color: Theme.overlay
                    font.family: row.note !== "" ? Theme.fontUi : Theme.fontMono
                    font.pixelSize: Theme.fsXs
                }
            }
            Rectangle {
                width: wsText.implicitWidth + 14
                height: 20
                radius: Theme.radius
                color: Theme.surface1
                Text { id: wsText; anchors.centerIn: parent; text: "ws " + row.modelData.ws; color: Theme.subtext; font.family: Theme.fontMono; font.pixelSize: Theme.fsXs }
            }
        }

        Rectangle {
            visible: row.actionLabel !== "" && rowHover.hovered
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: actText.implicitWidth + 18
            height: 26
            radius: 13
            color: actHover.hovered ? Theme.accent : Theme.surface1
            Text { id: actText; anchors.centerIn: parent; text: row.actionLabel; color: actHover.hovered ? Theme.crust : Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm }
            HoverHandler { id: actHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: row.action() }
        }

        HoverHandler { id: rowHover }
    }
}
