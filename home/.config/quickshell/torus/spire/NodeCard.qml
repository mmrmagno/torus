import QtQuick
import QtQuick.Layouts
import qs

Rectangle {
    id: card

    required property var node

    Layout.fillWidth: true
    implicitHeight: 92
    radius: Theme.rCard
    color: Qt.alpha(Theme.surface0, 0.7)
    border.width: 1
    border.color: card.node.ready ? Qt.alpha(Theme.surface1, 0.6) : Qt.alpha(Theme.red, 0.7)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 2
        RowLayout {
            spacing: Theme.sp3
            Rectangle { implicitWidth: 8; implicitHeight: 8; radius: 4; color: card.node.ready ? Theme.green : Theme.red }
            Text { text: card.node.name; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsLg; font.weight: Font.DemiBold }
            Text { text: card.node.role; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsXs }
        }
        Text { text: card.node.ready ? "Ready" : "NotReady"; color: card.node.ready ? Theme.subtext : Theme.red; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm }
        Text { text: "cpu " + (card.node.cpu || "?") + "  ·  mem " + (card.node.mem || "?"); color: Theme.subtext; font.family: Theme.fontMono; font.pixelSize: Theme.fsXs }
        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: (card.node.os || "").replace(/^Talos \((.*)\)$/, "Talos $1") + "  ·  k8s " + (card.node.kubelet || "")
            color: Theme.overlay
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsXs
        }
    }
}
