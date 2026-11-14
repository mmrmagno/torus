import QtQuick
import Quickshell.Widgets
import qs

Rectangle {
    id: look

    property string path: ""
    property string kind: "image"
    signal closed()

    visible: path !== ""
    onPathChanged: Store.look = path
    radius: Theme.rPanel
    color: Theme.crust
    MouseArea {
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onWheel: wheel => wheel.accepted = true
        onClicked: look.closed()
    }


    Item {
        id: stage
        anchors.fill: parent
        anchors.margins: 22
        anchors.bottomMargin: 58

        ClippingRectangle {
            visible: look.kind === "image"
            anchors.centerIn: parent
            width: pic.paintedWidth
            height: pic.paintedHeight
            radius: Theme.rCard
            color: "transparent"
            Image {
                id: pic
                x: (parent.width - width) / 2
                y: (parent.height - height) / 2
                width: stage.width
                height: stage.height
                source: look.visible && look.kind === "image" ? "file://" + look.path : ""
                sourceSize.width: 1920
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }
        }

        Loader {
            anchors.fill: parent
            active: look.visible && look.kind === "video"
            source: "QuickLookVideo.qml"
            onLoaded: item.path = Qt.binding(() => look.path)
        }

        Text {
            visible: look.kind === "image" && pic.status === Image.Error
            anchors.centerIn: parent
            text: "This file cannot be shown"
            color: Theme.subtext
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsMd
        }
    }

    Text {
        anchors.left: parent.left
        anchors.right: hint.left
        anchors.bottom: parent.bottom
        anchors.margins: 22
        text: look.path.split("/").pop()
        color: Theme.subtext
        elide: Text.ElideMiddle
        font.family: Theme.fontMono
        font.pixelSize: Theme.fsSm
    }

    KeyHints {
        id: hint
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 20
        hints: [["← / →", "next"], ["Space / Esc", "back"]]
    }
}
