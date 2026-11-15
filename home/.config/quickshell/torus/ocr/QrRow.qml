import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components

Rectangle {
    id: row

    required property var modelData
    required property int index
    property bool armed: false
    property string status: ""
    property bool failed: false
    readonly property bool link: modelData.kind === "link" && /^https?:\/\//i.test(modelData.text || "")
    readonly property bool wifi: modelData.kind === "wifi"
    signal copied(string text, bool secret)

    Layout.fillWidth: true
    implicitHeight: rowLayout.implicitHeight + 16
    radius: Theme.rCard
    color: Qt.alpha(Theme.accent, 0.10)
    border.width: 1
    border.color: Qt.alpha(Theme.accent, 0.35)

    Process {
        id: joiner
        command: ["torus-qrscan", "join", String(row.index), row.modelData.ssid || ""]
        stdout: StdioCollector {
            onStreamFinished: {
                row.failed = text.trim() !== "ok"
                row.status = (row.failed ? "Could not join " : "Joined ") + row.modelData.ssid
            }
        }
    }

    RowLayout {
        id: rowLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: 10
        spacing: Theme.sp4

        Text { text: row.wifi ? "󰖩" : "󰐲"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 20 }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                Layout.fillWidth: true
                text: (row.modelData.text || "").replace(/\s+/g, " ").trim()
                textFormat: Text.PlainText
                elide: Text.ElideMiddle
                maximumLineCount: 1
                color: Theme.text
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsMd
            }
            Text {
                Layout.fillWidth: true
                text: row.status !== "" ? row.status : (row.armed ? "Press Join again to connect" : (row.link ? "QR code, a link" : row.wifi ? (row.modelData.secure ? "QR code, a Wi-Fi with a password" : "QR code, an open Wi-Fi") : "QR code"))
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: row.failed && row.status !== "" ? Theme.red : (row.armed || row.status !== "" ? Theme.green : Theme.overlay)
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsSm
            }
        }
        PanelButton {
            visible: row.link
            label: "Open"
            icon: "󰏌"
            implicitHeight: 30
            onClicked: {
                if (!row.link)
                    return
                Quickshell.execDetached(["torus-launch", "xdg-open", row.modelData.text])
                Store.setOpen("ocr", false)
            }
        }
        PanelButton {
            visible: row.wifi
            label: joiner.running ? "Joining" : (row.armed ? "Join?" : "Join")
            icon: "󰖩"
            active: row.armed
            implicitHeight: 30
            onClicked: {
                if (joiner.running)
                    return
                if (!row.armed) {
                    row.armed = true
                    row.status = ""
                    return
                }
                row.armed = false
                joiner.running = true
            }
        }
        PanelButton {
            visible: row.wifi && row.modelData.secure
            label: "Copy password"
            icon: "󰌆"
            implicitHeight: 30
            onClicked: row.copied(row.modelData.password, true)
        }
        PanelButton {
            visible: !row.wifi
            label: "Copy"
            icon: "󰆏"
            implicitHeight: 30
            onClicked: row.copied(row.modelData.text, false)
        }
    }
}
