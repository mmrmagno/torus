import QtQuick
import Quickshell
import qs

Item {
    id: root

    property string icon: ""
    property string label: ""
    property color iconColor: Theme.accent
    property color labelColor: Theme.text
    property string tip: ""
    property Component card: null
    property bool open: false
    property bool cardHovered: false
    property bool available: true
    signal clicked
    signal rightClicked
    signal middleClicked
    signal scrolled(int delta)

    visible: available
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    Row {
        id: content
        spacing: 4
        anchors.verticalCenter: parent.verticalCenter

        Text {
            text: root.icon
            visible: root.icon !== ""
            color: hover.hovered ? Theme.lavender : root.iconColor
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSize + 1
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Text {
            text: root.label
            visible: root.label !== ""
            color: root.labelColor
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSize
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: {
            if (hovered && (root.card || root.tip !== "")) {
                closeTimer.stop()
                openTimer.restart()
            } else {
                openTimer.stop()
                closeTimer.restart()
            }
        }
    }

    Timer {
        id: openTimer
        interval: 300
        onTriggered: root.open = true
    }

    Timer {
        id: closeTimer
        interval: 180
        onTriggered: if (!hover.hovered && !root.cardHovered) root.open = false
    }

    LazyLoader {
        active: root.open
        PopupWindow {
            anchor.item: root
            anchor.rect: Qt.rect(0, 0, root.width, root.height + 12)
            anchor.edges: Edges.Bottom
            anchor.gravity: Edges.Bottom
            implicitWidth: frame.width
            implicitHeight: frame.height
            color: "transparent"
            visible: true

            Rectangle {
                id: frame
                width: body.implicitWidth + 24
                height: body.implicitHeight + 20
                radius: Theme.radius + 2
                color: Qt.alpha(Theme.mantle, 0.94)
                border.width: 1
                border.color: Qt.alpha(Theme.accent, 0.35)

                Loader {
                    id: body
                    anchors.centerIn: parent
                    sourceComponent: root.card || tipText
                }

                HoverHandler {
                    onHoveredChanged: {
                        root.cardHovered = hovered
                        if (!hovered)
                            closeTimer.restart()
                    }
                }
            }
        }
    }

    Component {
        id: tipText
        Text {
            text: root.tip
            color: Theme.text
            font.family: Theme.fontUi
            font.pixelSize: 12
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => {
            root.open = false
            if (mouse.button === Qt.RightButton)
                root.rightClicked()
            else if (mouse.button === Qt.MiddleButton)
                root.middleClicked()
            else
                root.clicked()
        }
        onWheel: wheel => root.scrolled(wheel.angleDelta.y > 0 ? 1 : -1)
    }
}
