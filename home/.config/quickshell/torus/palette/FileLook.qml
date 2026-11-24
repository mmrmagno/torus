import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs
import qs.components
import "../components/fileuri.mjs" as U

Rectangle {
    id: look

    property string path: ""
    property string kind: ""
    property string body: ""
    property string picPath: ""
    property bool loading: false

    visible: path !== ""
    radius: Theme.rCard
    color: Theme.crust
    border.width: 1
    border.color: Qt.alpha(Theme.accent, 0.35)
    onPathChanged: reload()

    function reload() {
        kind = ""
        body = ""
        picPath = ""
        loading = path !== ""
        if (path === "")
            return
        slow.restart()
        probe.asked = path
        probe.exec(["torus-look", path])
    }

    function sizeText(b) {
        const n = Number(b) || 0
        if (n < 1024)
            return n + " B"
        const u = ["KB", "MB", "GB", "TB"]
        let v = n / 1024, i = 0
        while (v >= 1024 && i < u.length - 1) {
            v /= 1024
            i++
        }
        return v.toFixed(v < 10 ? 1 : 0) + " " + u[i]
    }

    readonly property string shown: kind === "image" && picture.status === Image.Error ? "error" : kind
    readonly property var entries: kind === "folder" ? body.split("\n").filter(l => l !== "") : []
    readonly property string caption: {
        if (kind === "folder")
            return entries.length === 0 ? "empty folder" : entries.length + (entries.length >= 300 ? "+" : "") + " items"
        if (kind === "other") {
            const f = body.trim().split(" ")
            return sizeText(f[0]) + ", " + new Date(Number(f[1]) * 1000).toLocaleString(Qt.locale(), "d MMM yyyy HH:mm")
        }
        return kind
    }

    Timer { id: slow; interval: 150 }

    Process {
        id: probe
        property string asked: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (probe.asked !== look.path)
                    return
                const nl = text.indexOf("\n")
                const k = (nl < 0 ? text : text.slice(0, nl)).trim()
                const rest = nl < 0 ? "" : text.slice(nl + 1)
                look.loading = false
                look.kind = k === "" ? "error" : k
                if (k === "pdf")
                    look.picPath = rest.trim()
                else if (k === "image")
                    look.picPath = look.path
                else
                    look.body = rest
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

    Item {
        id: stage
        anchors.fill: parent
        anchors.margins: 16
        anchors.bottomMargin: 44

        ClippingRectangle {
            visible: look.picPath !== ""
            anchors.centerIn: parent
            width: picture.paintedWidth
            height: picture.paintedHeight
            radius: Theme.rCard - 4
            color: "transparent"
            Image {
                id: picture
                x: (parent.width - width) / 2
                y: (parent.height - height) / 2
                width: stage.width
                height: stage.height
                source: U.uriOf(look.picPath)
                sourceSize.width: 1600
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
            }
        }

        Loader {
            anchors.fill: parent
            active: look.visible && look.kind === "video"
            source: "../components/QuickLookVideo.qml"
            onLoaded: item.path = Qt.binding(() => look.path)
        }

        Flickable {
            id: textView
            anchors.fill: parent
            visible: look.kind === "text" || look.kind === "folder"
            clip: true
            contentHeight: bodyText.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            Text {
                id: bodyText
                width: textView.width
                textFormat: Text.PlainText
                wrapMode: look.kind === "text" ? Text.WrapAnywhere : Text.NoWrap
                elide: look.kind === "folder" ? Text.ElideRight : Text.ElideNone
                text: look.kind === "folder" ? look.entries.map(e => (e.endsWith("/") ? "󰉋  " : "󰈔  ") + e.replace(/\/$/, "")).join("\n") : look.body
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fsSm
                lineHeight: 1.15
            }
        }

        Text {
            anchors.centerIn: parent
            visible: look.kind === "other" || look.kind === "error" || (look.kind === "text" && look.body === "") || (look.kind === "image" && picture.status === Image.Error) || (look.loading && !slow.running)
            text: look.loading ? "Loading…" : look.kind === "error" || picture.status === Image.Error ? "Cannot read this file" : look.kind === "text" ? "This file is empty" : "No preview for this kind of file"
            color: Theme.subtext
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsMd
        }
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 14
        spacing: Theme.sp6
        Text {
            Layout.fillWidth: true
            text: look.path.split("/").filter(x => x).pop() + (look.caption && !look.loading ? "  (" + look.caption + ")" : "")
            color: Theme.subtext
            elide: Text.ElideMiddle
            font.family: Theme.fontMono
            font.pixelSize: Theme.fsSm
        }
        KeyHints {
            hints: [["↑ / ↓", "next"], ["↵", "open"], ["Shift Space / Esc", "back"]]
        }
    }
}
