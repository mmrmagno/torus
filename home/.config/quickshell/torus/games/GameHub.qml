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
    property bool loaded: false
    property string cutting: ""
    property string view: "games"
    property bool setting: false
    property bool clipSetting: false

    function setView(v) {
        if (view === "clips" && v !== "clips")
            library.keep()
        view = v
        if (v === "clips") {
            library.placing = true
            library.reload()
        }
    }

    function openSettings(g) {
        if (!g)
            return
        settings.open(g)
        setting = true
    }
    property bool failed: false
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

    property string keptGame: ""
    property bool placing: false

    function place() {
        placing = false
        grid.currentIndex = Math.max(0, shown.findIndex(g => g.id === keptGame))
    }

    Binding {
        target: Store
        property: "hubSpot"
        value: root.view + "|" + (root.selected ? root.selected.name : "") + "|" + library.game + "|" + library.starredOnly + "|" + library.sort
    }

    onVisibleChanged: if (!visible) {
        keptGame = selected ? selected.id : ""
        if (view === "clips")
            library.keep()
    } else {
        const keep = Store.recalls("games")
        cutting = Store.pendingCut
        Store.pendingCut = ""
        setting = false
        clipSetting = false
        setView(cutting !== "" ? "clips" : (keep ? view : "games"))
        if (!keep) {
            keptGame = ""
            library.forget()
        }
        search.text = ""
        place()
        placing = keptGame !== ""
        if (!loader.running)
            loader.running = true
        search.forceActiveFocus()
    }

    Process {
        id: loader
        command: ["torus-games"]
        onExited: code => root.failed = code !== 0 && root.games.length === 0
        stdout: StdioCollector {
            onStreamFinished: {
                root.games = text.split("\n").filter(l => l).map(l => {
                    const f = l.split("\t")
                    return { id: f[0], name: f[1], last: Number(f[2]) || 0, mins: Number(f[3]) || 0, art: f[4] || "" }
                })
                root.loaded = true
                if (root.placing)
                    root.place()
            }
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
                        const ctrl = event.modifiers & Qt.ControlModifier
                        if (root.setting) {
                            settings.key(event)
                            event.accepted = true
                            return
                        }
                        if (root.clipSetting) {
                            clipSheet.key(event)
                            event.accepted = true
                            return
                        }
                        if (root.view === "clips" && ctrl && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !library.busy) {
                            root.clipSetting = true
                            event.accepted = true
                            return
                        }
                        if ((event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) && !(root.view === "clips" && library.renaming)) {
                            root.setView(root.view === "games" ? "clips" : "games")
                            event.accepted = true
                            return
                        }
                        if (root.view === "clips") {
                            if (event.key === Qt.Key_Escape && !library.busy)
                                root.setView("games")
                            else if (!library.key(event))
                                return
                            event.accepted = true
                            return
                        }
                        if (event.key === Qt.Key_Escape)
                            Store.setOpen("games", false)
                        else if (event.key === Qt.Key_Right)
                            grid.moveCurrentIndexRight()
                        else if (event.key === Qt.Key_Left)
                            grid.moveCurrentIndexLeft()
                        else if (event.key === Qt.Key_Down)
                            grid.moveCurrentIndexDown()
                        else if (event.key === Qt.Key_Up)
                            grid.moveCurrentIndexUp()
                        else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && ctrl)
                            root.openSettings(root.selected)
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                            root.launch(root.selected)
                        else
                            return
                        event.accepted = true
                    }
                    Text {
                        visible: search.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.view === "clips" ? "type to find a clip" : root.games.length + " games, last played first"
                        color: Theme.overlay
                        font: search.font
                    }
                }
                Segmented {
                    options: ["games", "clips"]
                    labels: ["Games", "Clips"]
                    current: root.view
                    activeFocusOnTab: false
                    onPicked: value => {
                        root.setView(value)
                        search.forceActiveFocus()
                    }
                }
                PanelButton {
                    visible: root.view === "clips"
                    icon: "󰒓"
                    implicitHeight: 28
                    activeFocusOnTab: false
                    onClicked: root.clipSetting = true
                }
                Text {
                    visible: !!root.selected && root.view === "games"
                    text: root.selected ? root.hours(root.selected.mins) + "  ·  " + root.ago(root.selected.last) : ""
                    color: Theme.subtext
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsSm
                }
            }

            ClipLibrary {
                id: library
                visible: root.view === "clips"
                Layout.fillWidth: true
                Layout.fillHeight: true
                filter: root.filter
                onCutRequested: path => root.cutting = path
            }

            GridView {
                id: grid
                visible: root.view === "games"
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
                        scale: cell.current ? 1.03 : (tileHover.hovered ? 1.015 : 1)
                        Behavior on scale { NumberAnimation { duration: 120 } }

                        Rectangle {
                            id: jobBar
                            readonly property var job: SteamLog.jobFor(cell.modelData.id, "shader") || SteamLog.jobFor(cell.modelData.id, "download")
                            visible: !!job
                            z: 5
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 30
                            color: Qt.alpha(Theme.crust, 0.85)
                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.sp3
                                ProgressRing {
                                    width: 14
                                    height: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    value: jobBar.job ? jobBar.job.pct / 100 : 0
                                    tint: jobBar.job && jobBar.job.kind === "download" ? Theme.sapphire : Theme.accent
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: jobBar.job ? (jobBar.job.kind === "download" ? "update " : "shaders ") + jobBar.job.pct + "%" : ""
                                    color: Theme.text
                                    font.family: Theme.fontUi
                                    font.pixelSize: Theme.fsXs
                                }
                            }
                        }

                        Image {
                            anchors.fill: parent
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
                        Rectangle {
                            anchors.fill: parent
                            z: 7
                            radius: Theme.rCard
                            color: "transparent"
                            border.width: cell.current ? 3 : (tileHover.hovered ? 1 : 0)
                            border.color: cell.current ? Theme.accent : Qt.alpha(Theme.accent, 0.5)
                        }
                        Rectangle {
                            id: cog
                            visible: tileHover.hovered || cell.current
                            z: 6
                            x: card.width - width - 8
                            y: 8
                            width: 28
                            height: 28
                            radius: 14
                            color: cogHover.hovered ? Theme.accent : Qt.alpha(Theme.crust, 0.8)
                            Behavior on color { ColorAnimation { duration: Theme.durFast } }
                            Text { anchors.centerIn: cog; text: "󰒓"; color: cogHover.hovered ? Theme.crust : Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fsMd }
                            HoverHandler { id: cogHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: {
                                    grid.currentIndex = cell.index
                                    root.openSettings(cell.modelData)
                                }
                            }
                        }
                        TapHandler {
                            onTapped: (point, button) => {
                                if (cog.visible && cog.contains(cog.mapFromItem(card, point.position)))
                                    return
                                grid.currentIndex === cell.index ? root.launch(cell.modelData) : grid.currentIndex = cell.index
                            }
                            onDoubleTapped: (point, button) => {
                                if (!(cog.visible && cog.contains(cog.mapFromItem(card, point.position))))
                                    root.launch(cell.modelData)
                            }
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

                CardState {
                    anchors.fill: parent
                    status: grid.count > 0 ? "ready" : (root.failed ? "error" : (!root.loaded ? "loading" : "empty"))
                    text: status === "error" ? "torus-games failed, Steam library not readable" : (root.games.length === 0 ? "No Steam games found" : "nothing matches")
                    onRetry: { root.failed = false; loader.running = true }
                }
            }

            KeyHints {
                Layout.fillWidth: true
                visible: root.view === "games"
                hints: [["↵", "play"], ["Ctrl ↵", "settings"], ["← / →", "move"], ["type", "filter"], ["Tab", "clips"], ["Esc", "close"]]
            }
        }

        SettingsSheet {
            id: clipSheet
            anchors.fill: parent
            z: 9
            visible: root.clipSetting
            title: "Clip settings"
            note: (library.total / 1073741824).toFixed(1) + " GB of clips in ~/Videos/Clips"
            rows: [{ key: "budget", label: "Auto cleanup", note: library.budget > 0 ? "over " + library.budget + " GB the oldest clips go to the trash, favorites never" : "off: nothing is ever removed", values: ["0", "25", "50", "100"], labels: ["Off", "25 GB", "50 GB", "100 GB"] }]
            values: ({ budget: String(library.budget) })
            onPicked: (key, value) => library.setBudget(Number(value))
            moreHints: clipTrash.count > 0 ? [["Del", clipTrash.armed ? "again: empty for good" : "empty trash"]] : []
            onDeletePressed: clipTrash.empty()
            TrashMeter { id: clipTrash; Layout.fillWidth: true }
            onClosed: {
                root.clipSetting = false
                search.forceActiveFocus()
            }
        }

        GameSettings {
            id: settings
            anchors.fill: parent
            z: 9
            visible: root.setting
            onClosed: {
                root.setting = false
                search.forceActiveFocus()
            }
        }

        Loader {
            id: cutter
            anchors.fill: parent
            z: 10
            active: root.cutting !== ""
            sourceComponent: cutterView
            onLoaded: item.open(root.cutting)
        }

        Component {
            id: cutterView
            ClipCutter {
                onClosed: {
                    root.cutting = ""
                    search.forceActiveFocus()
                }
                onSaved: p => {
                    Play.load(Play.shownId)
                    library.reload()
                }
            }
        }
    }
}
