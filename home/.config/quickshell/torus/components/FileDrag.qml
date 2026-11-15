import QtQuick
import "fileuri.mjs" as U

Item {
    id: fileDrag

    property string path: ""
    readonly property bool dragging: handler.active
    readonly property string uri: U.uriOf(path)

    Drag.active: handler.active && uri !== ""
    Drag.dragType: Drag.Automatic
    Drag.supportedActions: Qt.CopyAction
    Drag.proposedAction: Qt.CopyAction
    Drag.mimeData: ({ "text/uri-list": U.uriList(fileDrag.path) })

    DragHandler {
        id: handler
        target: null
        enabled: fileDrag.uri !== ""
        cursorShape: Qt.DragCopyCursor
    }
}
