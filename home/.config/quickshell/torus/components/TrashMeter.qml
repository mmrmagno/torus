import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs

RowLayout {
    id: meter

    property int count: 0
    property real bytes: 0
    property bool armed: false
    property bool loaded: false
    spacing: Theme.sp5

    function refresh() {
        if (!status.running)
            status.running = true
    }

    function empty() {
        if (count === 0)
            return
        if (!armed) {
            armed = true
            disarm.restart()
            return
        }
        armed = false
        if (!emptier.running)
            emptier.running = true
    }

    function size(b) {
        return b >= 1073741824 ? (b / 1073741824).toFixed(1) + " GB" : (b >= 1048576 ? (b / 1048576).toFixed(0) + " MB" : Math.max(1, Math.round(b / 1024)) + " KB")
    }

    onVisibleChanged: if (visible) {
        armed = false
        refresh()
    }

    Timer { id: disarm; interval: 3000; onTriggered: meter.armed = false }

    Process {
        id: status
        command: ["torus-trash", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const s = JSON.parse(text)
                    meter.count = s.count || 0
                    meter.bytes = s.bytes || 0
                } catch (e) {
                    meter.count = 0
                    meter.bytes = 0
                }
                meter.loaded = true
            }
        }
    }

    Process {
        id: emptier
        command: ["torus-trash", "empty"]
        onExited: {
            Store.sound("delete")
            meter.refresh()
        }
    }

    Connections {
        target: Store
        function onTrashed() { if (meter.visible) settle.restart() }
        function onRestored() { if (meter.visible) meter.refresh() }
    }
    Timer { id: settle; interval: 600; onTriggered: meter.refresh() }

    Text { text: "󰩹"; color: meter.count > 0 ? Theme.accent : Theme.overlay; font.family: Theme.fontMono; font.pixelSize: Theme.fsXl; Layout.leftMargin: 10 }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        Text {
            Layout.fillWidth: true
            text: !meter.loaded ? "Trash" : (meter.count === 0 ? "Nothing of mine in the trash" : meter.count + (meter.count === 1 ? " file" : " files") + " in the trash, " + meter.size(meter.bytes))
            color: Theme.text
            elide: Text.ElideRight
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsMd
        }
        Text {
            Layout.fillWidth: true
            text: "what torus deleted for me; other apps' trash is left alone"
            color: Theme.overlay
            elide: Text.ElideRight
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsXs
        }
    }
    PanelButton {
        visible: meter.count > 0
        icon: "󰆴"
        label: meter.armed ? "Empty for good? Again" : "Empty"
        implicitHeight: 28
        activeFocusOnTab: false
        Layout.rightMargin: 8
        onClicked: meter.empty()
    }
}
