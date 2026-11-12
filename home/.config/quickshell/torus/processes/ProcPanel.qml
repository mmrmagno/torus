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

    property var all: []
    property string query: ""
    property string sortBy: "cpu"
    property bool mineOnly: true
    property int selected: 0
    property int confirm: -1
    property string status: ""
    readonly property var shown: {
        const q = query.toLowerCase()
        const rows = all.filter(p => (!mineOnly || p.mine) && (q === "" || p.name.toLowerCase().includes(q) || p.cmd.toLowerCase().includes(q) || String(p.pid) === q))
        const key = sortBy
        rows.sort((a, b) => key === "name" ? a.name.localeCompare(b.name) : (b[key] - a[key]) || (b.cpu - a.cpu))
        return rows.slice(0, 80)
    }
    onShownChanged: selected = Math.max(0, Math.min(selected, shown.length - 1))

    function size(b) {
        return b >= 1073741824 ? (b / 1073741824).toFixed(1) + " G" : b >= 1048576 ? Math.round(b / 1048576) + " M" : b > 0 ? Math.round(b / 1024) + " K" : "–"
    }
    function stop(p) {
        if (!p)
            return
        if (confirm !== p.pid) {
            confirm = p.pid
            confirmReset.restart()
            return
        }
        confirm = -1
        killer.command = ["torus-ps", "kill", String(p.pid)]
        killer.running = true
    }

    screen: Store.screenFor("processes")
    visible: Store.isOpen("processes") || motion.leaving
    onVisibleChanged: {
        if (!visible)
            return
        query = ""
        selected = 0
        status = ""
        search.text = ""
        search.forceActiveFocus()
        lister.running = true
    }
    anchors.top: true
    margins.top: Store.barGap
    implicitWidth: Math.min(860, (screen ? screen.width : 900) - 40)
    implicitHeight: Math.min(Store.panelRoom(screen, 20), 640)
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "torus-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Store.isOpen("processes") && !Store.moving ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        active: Store.isOpen("processes") && root.backingWindowVisible
        windows: [root]
        onCleared: Store.setOpen("processes", false)
    }

    Process {
        id: lister
        command: ["torus-ps"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.all = JSON.parse(text).processes || []
                } catch (e) {}
            }
        }
    }
    Process {
        id: killer
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.status = JSON.parse(text).message || ""
                } catch (e) {}
                lister.running = true
            }
        }
    }
    Timer {
        interval: 2000
        repeat: true
        running: Store.isOpen("processes")
        onTriggered: if (!lister.running) lister.running = true
    }
    Timer { id: confirmReset; interval: 3000; onTriggered: root.confirm = -1 }

    Rectangle {
        anchors.fill: parent
        PanelMotion { id: motion; target: parent; shown: Store.isOpen("processes") && !Store.moving }
        radius: Theme.rPanel
        color: Qt.alpha(Theme.base, Theme.glassCard)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.35)
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: Theme.sp5

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sp4
                Text { text: "󰍛"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 22 }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 34
                    radius: Theme.rSm
                    color: Qt.alpha(Theme.base, 0.6)
                    border.width: 1
                    border.color: search.activeFocus ? Theme.accent : Theme.surface1
                    TextInput {
                        id: search
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsBase
                        clip: true
                        onTextChanged: root.query = text
                        Keys.onEscapePressed: Store.setOpen("processes", false)
                        Keys.onUpPressed: root.selected = Math.max(0, root.selected - 1)
                        Keys.onDownPressed: root.selected = Math.min(root.shown.length - 1, root.selected + 1)
                        Keys.onDeletePressed: root.stop(root.shown[root.selected])
                        Keys.onTabPressed: {
                            const order = ["cpu", "rss", "gpu", "name"]
                            root.sortBy = order[(order.indexOf(root.sortBy) + 1) % order.length]
                        }
                    }
                    Text {
                        anchors.fill: search
                        verticalAlignment: Text.AlignVCenter
                        visible: search.text === ""
                        text: "search by name, command or PID   ·   ↑↓ select   ·   Del stop   ·   Tab sort"
                        color: Theme.overlay
                        font: search.font
                        elide: Text.ElideRight
                    }
                }
                PanelButton { label: root.mineOnly ? "Mine" : "All users"; implicitHeight: 34; active: !root.mineOnly; onClicked: root.mineOnly = !root.mineOnly }
                PanelButton { label: "btop"; implicitHeight: 34; onClicked: { Quickshell.execDetached(["torus-launch", "kitty", "--title", "btop", "-e", "btop"]); Store.setOpen("processes", false) } }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 44
                spacing: Theme.sp4
                Header { label: "Process"; key: "name"; Layout.fillWidth: true; align: Text.AlignLeft }
                Header { label: "PID"; key: ""; Layout.preferredWidth: 64 }
                Header { label: "CPU"; key: "cpu"; Layout.preferredWidth: 64 }
                Header { label: "Memory"; key: "rss"; Layout.preferredWidth: 74 }
                Header { label: "GPU"; key: "gpu"; Layout.preferredWidth: 64 }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: root.shown
                currentIndex: root.selected
                boundsBehavior: Flickable.StopAtBounds
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === root.selected
                    readonly property bool asking: root.confirm === modelData.pid
                    width: list.width
                    height: 40
                    radius: Theme.rSm
                    color: sel ? Qt.alpha(Theme.accent, 0.16) : rowHover.hovered ? Theme.surface0 : "transparent"
                    HoverHandler { id: rowHover }
                    TapHandler { onTapped: root.selected = row.index }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 6
                        spacing: Theme.sp4
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text { Layout.fillWidth: true; text: row.modelData.name; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd; font.weight: Font.DemiBold; elide: Text.ElideRight }
                            Text { Layout.fillWidth: true; text: row.modelData.cmd; color: Theme.overlay; font.family: Theme.fontMono; font.pixelSize: Theme.fsXs; elide: Text.ElideMiddle }
                        }
                        Cell { text: row.modelData.pid; Layout.preferredWidth: 64; dim: true }
                        Cell { text: row.modelData.cpu.toFixed(1) + "%"; Layout.preferredWidth: 64; hot: row.modelData.cpu > 50 }
                        Cell { text: root.size(row.modelData.rss); Layout.preferredWidth: 74; hot: row.modelData.rss > 4294967296 }
                        Cell { text: root.size(row.modelData.gpu); Layout.preferredWidth: 64; dim: row.modelData.gpu === 0 }
                        Rectangle {
                            implicitWidth: row.asking ? 64 : 28
                            implicitHeight: 28
                            radius: 14
                            visible: row.modelData.mine && (rowHover.hovered || row.sel || row.asking)
                            color: row.asking ? Theme.red : killHover.hovered ? Qt.alpha(Theme.red, 0.25) : "transparent"
                            Behavior on implicitWidth { NumberAnimation { duration: Theme.durFast } }
                            Text {
                                anchors.centerIn: parent
                                text: row.asking ? "stop?" : "󰅖"
                                color: row.asking ? Theme.crust : Theme.red
                                font.family: row.asking ? Theme.fontUi : Theme.fontMono
                                font.pixelSize: row.asking ? Theme.fsSm : Theme.fsLg
                            }
                            HoverHandler { id: killHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: root.stop(row.modelData) }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.status !== "" ? root.status : root.shown.length + " of " + root.all.filter(p => !root.mineOnly || p.mine).length + " processes · CPU is the share of all cores"
                color: root.status !== "" ? Theme.green : Theme.overlay
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsXs
            }
        }
    }

    component Header: Text {
        property string label: ""
        property string key: ""
        property int align: Text.AlignRight
        text: label + (root.sortBy === key && key !== "" ? (key === "name" ? " ↑" : " ↓") : "")
        horizontalAlignment: align
        color: root.sortBy === key ? Theme.accent : Theme.subtext
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsSm
        font.weight: Font.DemiBold
        HoverHandler { enabled: parent.key !== ""; cursorShape: Qt.PointingHandCursor }
        TapHandler { enabled: parent.key !== ""; onTapped: root.sortBy = parent.key }
    }

    component Cell: Text {
        property bool hot: false
        property bool dim: false
        horizontalAlignment: Text.AlignRight
        color: hot ? Theme.peach : dim ? Theme.overlay : Theme.text
        font.family: Theme.fontMono
        font.pixelSize: Theme.fsSm
    }
}
