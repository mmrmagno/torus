import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs

Rectangle {
    id: qr

    property string mode: "text"
    property string payload: ""
    property string caption: ""
    property string status: "idle"
    property string png: ""

    radius: Theme.rCard
    color: Theme.crust
    border.width: 1
    border.color: Qt.alpha(Theme.accent, 0.35)
    onPayloadChanged: make()
    onModeChanged: make()
    onVisibleChanged: if (visible) make()

    function make() {
        if (!visible || payload === "") {
            status = payload === "" ? "empty" : "idle"
            png = ""
            return
        }
        status = "loading"
        maker.asked = mode + "\n" + payload
        maker.exec(["torus-qr", mode, "--", payload])
    }

    readonly property string message: {
        switch (status) {
        case "too-long": return "Too long for a QR code"
        case "empty": return "Nothing to show"
        case "missing": return "Install qrencode to show QR codes"
        case "not-connected": return "Not connected to this network"
        case "no-password": return "NetworkManager has no saved password for this network"
        case "error": return "Could not make the code"
        default: return ""
        }
    }

    Process {
        id: maker
        property string asked: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (maker.asked !== qr.mode + "\n" + qr.payload)
                    return
                const t = text.trim()
                if (t.startsWith("ok ")) {
                    qr.png = t.slice(3)
                    qr.status = "ready"
                } else {
                    qr.png = ""
                    qr.status = t === "" ? "error" : t
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onWheel: wheel => wheel.accepted = true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: Theme.sp5

        Item {
            id: stage
            Layout.fillWidth: true
            Layout.fillHeight: true
            readonly property real side: Math.min(width, height)

            ClippingRectangle {
                visible: qr.status === "ready"
                anchors.centerIn: parent
                width: stage.side
                height: stage.side
                radius: Theme.rCard - 4
                color: "white"
                Image {
                    anchors.fill: parent
                    source: qr.png !== "" ? "file://" + qr.png : ""
                    fillMode: Image.PreserveAspectFit
                    smooth: false
                    cache: false
                    asynchronous: true
                }
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - 20
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: qr.message !== ""
                text: qr.message
                color: Theme.subtext
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsMd
            }
        }

        Text {
            Layout.fillWidth: true
            visible: qr.caption !== ""
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: qr.caption
            color: Theme.subtext
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsSm
        }
    }
}
