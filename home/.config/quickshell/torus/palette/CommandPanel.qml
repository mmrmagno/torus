import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.components
import qs.services

PanelWindow {
    id: root

    readonly property var selected: Commands.results[list.currentIndex] || null

    screen: Store.screenFor("palette")
    visible: Store.isOpen("palette") || motion.leaving
    implicitWidth: 660
    implicitHeight: 540
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "torus-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Store.isOpen("palette") ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onVisibleChanged: if (visible) {
        Commands.snapshot()
        search.text = ""
        Commands.query = ""
        list.currentIndex = 0
        search.forceActiveFocus()
        if (Commands.pendingScope !== "") {
            Commands.setScope(Commands.pendingScope)
            Commands.pendingScope = ""
        }
    }

    Connections {
        target: Commands
        function onModeChanged() {
            list.currentIndex = 0
        }
    }

    Rectangle {
        id: frame
        PanelMotion {
            id: motion
            target: frame
            shown: Store.isOpen("palette")
        }
        readonly property real want: 28 + 48 + 24 + 20 + 3 * Theme.sp4 + (list.count === 0 ? 96 : Math.min(list.contentHeight, 400))
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.min(root.implicitHeight, Math.max(220, want))
        Behavior on height { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
        transformOrigin: Item.Top
        radius: Theme.rPanel
        color: Qt.alpha(Theme.base, Theme.glassCard)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.35)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: Theme.sp4

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                radius: 14
                color: Theme.surface0
                border.width: 1
                border.color: Qt.alpha(Theme.accent, 0.5)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: Theme.sp6
                    Text {
                        text: Commands.glyph
                        color: Theme.accent
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fsTitle
                    }
                    TextInput {
                        id: search
                        Connections {
                            target: Commands
                            function onFill(text) {
                                search.text = text
                                search.cursorPosition = text.length
                            }
                        }
                        Layout.fillWidth: true
                        color: Theme.text
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsXl
                        clip: true
                        onTextChanged: {
                            Commands.query = text
                            list.currentIndex = 0
                        }
                        Keys.onPressed: event => {
                            const ctrl = event.modifiers & Qt.ControlModifier
                            const alt = event.modifiers & Qt.AltModifier
                            if (event.key === Qt.Key_Escape)
                                Store.setOpen("palette", false)
                            else if (event.key === Qt.Key_Down)
                                list.incrementCurrentIndex()
                            else if (event.key === Qt.Key_Up)
                                list.decrementCurrentIndex()
                            else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier)))
                                Commands.cycleScope(-1)
                            else if (event.key === Qt.Key_Tab)
                                Commands.cycleScope(1)
                            else if (event.key === Qt.Key_F1)
                                Commands.put("?")
                            else if (event.key === Qt.Key_Backspace && search.text === "" && Commands.mode !== "all")
                                Commands.setScope("all")
                            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                Commands.run(root.selected, ctrl ? "ctrl" : (alt && (event.modifiers & Qt.ShiftModifier) ? "layout" : (alt ? "alt" : "")))
                            else
                                return
                            event.accepted = true
                        }
                        Text {
                            visible: search.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: Commands.mode === "all" ? "apps, windows, projects, math, paths…" : "search " + (Commands.current ? Commands.current.name.toLowerCase() : "") + "…"
                            color: Theme.overlay
                            font: search.font
                        }
                    }
                }
            }

            ListView {
                id: scopeBar
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                orientation: ListView.Horizontal
                spacing: Theme.sp2
                clip: true
                interactive: false
                model: Commands.scopes
                currentIndex: Math.max(0, Commands.scopes.findIndex(s => s.key === Commands.mode))
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                delegate: Rectangle {
                    id: chip
                    required property var modelData
                    readonly property bool on: modelData.key === Commands.mode
                    width: chipRow.implicitWidth + 16
                    height: 24
                    radius: 12
                    color: on ? Qt.alpha(Theme.accent, 0.22) : (chipHover.hovered ? Theme.surface0 : "transparent")
                    border.width: on ? 1 : 0
                    border.color: Qt.alpha(Theme.accent, 0.55)
                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: Theme.sp2
                        Text {
                            text: chip.modelData.glyph
                            color: chip.on ? Theme.accent : Theme.overlay
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fsSm
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: chip.modelData.name
                            color: chip.on ? Theme.text : Theme.subtext
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fsSm
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: { Commands.setScope(chip.modelData.key); search.forceActiveFocus() } }
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Theme.sp2
                model: Commands.results
                highlightMoveDuration: 100
                delegate: Column {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool head: !!modelData.section && (index === 0 || (list.model[index - 1] || {}).section !== modelData.section)
                    readonly property bool compact: modelData.kind === "help"
                    width: ListView.view.width
                    spacing: 0

                    Text {
                        visible: row.head
                        height: 24
                        verticalAlignment: Text.AlignBottom
                        leftPadding: 12
                        bottomPadding: 4
                        text: row.modelData.section || ""
                        color: Theme.overlay
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsXs
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.6
                        font.capitalization: Font.AllUppercase
                    }

                    Rectangle {
                        width: row.width
                        height: row.compact ? 40 : 52
                        radius: Theme.rCard
                        color: row.ListView.isCurrentItem ? Qt.alpha(Theme.accent, 0.18) : (hover.hovered ? Theme.surface0 : "transparent")
                        border.width: row.ListView.isCurrentItem ? 1 : 0
                        border.color: Qt.alpha(Theme.accent, 0.5)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 14
                            spacing: Theme.sp6

                            Item {
                                Layout.preferredWidth: row.compact ? 24 : 30
                                Layout.preferredHeight: row.compact ? 24 : 30
                                IconImage {
                                    anchors.fill: parent
                                    visible: !!row.modelData.icon
                                    source: row.modelData.icon || ""
                                }
                                Rectangle {
                                    anchors.centerIn: parent
                                    visible: !!row.modelData.swatch
                                    width: 24
                                    height: 24
                                    radius: 7
                                    color: row.modelData.swatch || "transparent"
                                    border.width: 1
                                    border.color: Qt.alpha(Theme.text, 0.15)
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: !row.modelData.icon && !row.modelData.swatch
                                    text: row.modelData.glyph || "󰀻"
                                    color: Theme.accent
                                    font.family: Theme.fontMono
                                    font.pixelSize: row.compact ? 16 : 20
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData.title
                                    color: Theme.text
                                    font.family: Theme.fontUi
                                    font.pixelSize: row.compact ? Theme.fsBase : Theme.fsLg
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: !!row.modelData.sub
                                    text: row.modelData.sub || ""
                                    color: Theme.subtext
                                    font.family: Theme.fontUi
                                    font.pixelSize: row.compact ? Theme.fsXs : Theme.fsSm
                                    elide: Text.ElideMiddle
                                }
                            }

                            Rectangle {
                                Layout.preferredHeight: 20
                                Layout.preferredWidth: kind.implicitWidth + 14
                                radius: Theme.radius
                                color: row.compact ? Theme.surface0 : Theme.surface1
                                Text {
                                    id: kind
                                    anchors.centerIn: parent
                                    text: row.modelData.chip || row.modelData.kind
                                    color: row.compact ? Theme.accent : Theme.subtext
                                    font.family: row.compact ? Theme.fontMono : Theme.fontUi
                                    font.pixelSize: Theme.fsXs
                                }
                            }
                        }

                        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: Commands.run(row.modelData) }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 40
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    visible: list.count === 0
                    text: Commands.mode !== "all" ? (Commands.term === "" ? "type to search" : "searching…") : (Commands.term === "" ? "Type to search everything. Tab picks a scope, ? lists them all." : "nothing matches")
                    color: Theme.overlay
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsBase
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 20
                spacing: Theme.sp6

                Repeater {
                    model: root.selected ? [["↵", Commands.enterLabel(root.selected)], ["Ctrl ↵", root.selected.ctrl ? root.selected.ctrl.label : ""], ["Alt ↵", root.selected.alt ? root.selected.alt.label : ""], ["Alt Shift ↵", root.selected.layout ? root.selected.layout.label : ""]].filter(k => k[1] !== "") : []
                    Row {
                        id: keyHint
                        required property var modelData
                        spacing: Theme.sp2
                        Keycap { text: keyHint.modelData[0]; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: keyHint.modelData[1]; color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
                Item { Layout.fillWidth: true }
                Row {
                    spacing: Theme.sp2
                    Keycap { text: "Tab"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "scope"; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; anchors.verticalCenter: parent.verticalCenter }
                }
                Row {
                    spacing: Theme.sp2
                    Keycap { text: "?"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "help"; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }
}
