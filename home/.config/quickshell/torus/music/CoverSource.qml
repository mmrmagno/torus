import QtQuick
import qs.services

Item {
    id: root

    property var row: null
    property string late: ""
    readonly property string url: root.row ? Music.fileUrl(root.row.cover || root.late) : ""

    visible: false
    onRowChanged: late = Music.lateCover(row)
    Component.onCompleted: late = Music.lateCover(row)

    Connections {
        target: Music
        function onCoverLanded(source, coverId, path) {
            if (root.row && root.row.source === source && String(root.row.coverId || "") === coverId)
                root.late = path
        }
    }
}
