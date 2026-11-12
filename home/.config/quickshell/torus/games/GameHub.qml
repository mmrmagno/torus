import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.components
import qs.services

PanelWindow {
    id: root

    property var games: []
    property string filter: ""
    readonly property var shown: games.filter(g => filter === "" || g.name.toLowerCase().includes(filter.toLowerCase()))
    readonly property var selected: shown[grid.currentIndex] || null

    function ago(t) {
        if (!t)
            return "never played"
        const d = Math.floor((Date.now() / 1000 - t) / 86400)
        return d < 1 ? "played today" : d === 1 ? "played yesterday" : d < 60 ? "played " + d + " d ago" : "played " + Math.floor(d / 30) + " mo ago"
    }

    function hours(m) {
        return m < 60 ? m + " min" : Math.round(m / 60) + " h"
    }

    function launch(g) {
        if (!g)
            return
        Quickshell.execDetached(["torus-launch", "xdg-open", "steam://rungameid/" + g.id])
        Store.setOpen("games", false)
    }

    screen: Store.screenFor("games")
    visible: Store.isOpen("games") || motion.leaving
    implicitWidth: Math.floor(Math.min(1020, (screen ? screen.width : 1280) - 80))
    implicitHeight: Math.floor(Math.min(660, (screen ? screen.height : 800) - 120))
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "torus-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Store.isOpen("games") ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onVisibleChanged: if (visible) {
        dock.mode = "grid"
        search.text = ""
        grid.currentIndex = 0
        if (!loader.running)
            loader.running = true
        search.forceActiveFocus()
    }

    Process {
        id: loader
        command: ["torus-games"]
        stdout: StdioCollector {
            onStreamFinished: root.games = text.split("\n").filter(l => l).map(l => {
                const f = l.split("\t")
                return { id: f[0], name: f[1], last: Number(f[2]) || 0, mins: Number(f[3]) || 0, art: f[4] || "" }
            })
        }
    }

    Rectangle {
        id: frame
        PanelMotion {
            id: motion
            target: frame
            shown: Store.isOpen("games")
        }
        anchors.fill: parent
        radius: Theme.rPanel
        color: Qt.alpha(Theme.base, Theme.glassCard)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.35)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: Theme.sp5

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sp6
                Text {
                    text: "󰊴"
                    color: Theme.accent
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fsTitle
                }
                TextInput {
                    id: search
                    Layout.fillWidth: true
                    color: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsXl
                    clip: true
                    onTextChanged: {
                        root.filter = text
                        grid.currentIndex = 0
                    }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Tab) {
                            dock.mode = dock.mode === "grid" ? (Play.clips.length > 0 ? "clips" : "settings") : (dock.mode === "clips" ? "settings" : "grid")
                            event.accepted = true
                            return
                        }
                        if (dock.mode !== "grid" && event.key !== Qt.Key_Escape) {
                            const ctrl = event.modifiers & Qt.ControlModifier
                            if (dock.mode === "clips" && (event.key === Qt.Key_Left || event.key === Qt.Key_Right))
                                dock.step(event.key === Qt.Key_Right ? 1 : -1)
                            else if (dock.mode === "clips" && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter))
                                dock.play()
                            else if (dock.mode === "clips" && event.key === Qt.Key_Delete)
                                dock.remove()
                            else if (dock.mode === "clips" && ctrl && event.key === Qt.Key_C)
                                dock.copy()
                            else if (dock.mode === "settings" && (event.key === Qt.Key_Up || event.key === Qt.Key_Down))
                                dock.step(event.key === Qt.Key_Down ? 1 : -1)
                            else if (dock.mode === "settings" && (event.key === Qt.Key_Left || event.key === Qt.Key_Right))
                                dock.cycle(event.key === Qt.Key_Right ? 1 : -1)
                            else
                                return
                            event.accepted = true
                            return
                        }
                        if (event.key === Qt.Key_Escape)
                            dock.mode === "grid" ? Store.setOpen("games", false) : dock.mode = "grid"
                        else if (event.key === Qt.Key_Right)
                            grid.moveCurrentIndexRight()
                        else if (event.key === Qt.Key_Left)
                            grid.moveCurrentIndexLeft()
                        else if (event.key === Qt.Key_Down)
                            grid.moveCurrentIndexDown()
                        else if (event.key === Qt.Key_Up)
                            grid.moveCurrentIndexUp()
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                            root.launch(root.selected)
                        else
                            return
                        event.accepted = true
                    }
                    Text {
                        visible: search.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.games.length + " games, last played first"
                        color: Theme.overlay
                        font: search.font
                    }
                }
                Text {
                    visible: !!root.selected
                    text: root.selected ? root.hours(root.selected.mins) + "  ·  " + root.ago(root.selected.last) : ""
                    color: Theme.subtext
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsSm
                }
            }

            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 150)))
                cellHeight: Math.floor(cellWidth * 1.5) + 34
                model: root.shown
                highlightMoveDuration: 120
                keyNavigationWraps: false

                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property bool current: GridView.isCurrentItem
                    width: grid.cellWidth
                    height: grid.cellHeight

                    ClippingRectangle {
                        id: card
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 4
                        width: cell.width - 14
                        height: Math.floor(width * 1.5)
                        radius: Theme.rCard
                        color: Theme.surface0
                        border.width: cell.current ? 2 : 0
                        border.color: Theme.accent
                        scale: cell.current ? 1.03 : (tileHover.hovered ? 1.015 : 1)
                        Behavior on scale { NumberAnimation { duration: 120 } }

                        Image {
                            anchors.fill: parent
                            anchors.margins: cell.current ? 2 : 0
                            source: cell.modelData.art ? "file://" + cell.modelData.art : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 300
                            visible: status === Image.Ready
                        }
                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 16
                            visible: !cell.modelData.art
                            text: cell.modelData.name
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            color: Theme.subtext
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fsBase
                        }
                        HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: grid.currentIndex === cell.index ? root.launch(cell.modelData) : grid.currentIndex = cell.index
                            onDoubleTapped: root.launch(cell.modelData)
                        }
                    }
                    Text {
                        anchors.top: card.bottom
                        anchors.topMargin: 6
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: card.width
                        text: cell.modelData.name
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        color: cell.current ? Theme.text : Theme.subtext
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsSm
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: grid.count === 0
                    text: root.games.length === 0 ? "No Steam games found" : "nothing matches"
                    color: Theme.overlay
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsBase
                }
            }

            GameDock {
                id: dock
                game: root.selected
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sp6
                Text { text: "↵ play  ·  arrows move  ·  type to filter  ·  Tab clips and settings  ·  Esc closes"; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm }
            }
        }
    }
}
