import QtQuick
import "fileuri.mjs" as U

Item {
    id: fileDrag

    property string path: ""
    property Item picture: null
    property url image: ""
    property string grabbedFor: ""
    readonly property bool dragging: handler.active
    readonly property string uri: U.uriOf(path)

    function prepare() {
        if (!picture || path === "" || grabbedFor === path || picture.width <= 0)
            return
        const want = path
        picture.grabToImage(result => {
            if (fileDrag.path === want) {
                fileDrag.image = result.url
                fileDrag.grabbedFor = want
            }
        }, Qt.size(180, Math.round(180 * picture.height / picture.width)))
    }

    onPathChanged: {
        image = ""
        grabbedFor = ""
    }

    Drag.active: handler.active && uri !== ""
    Drag.dragType: Drag.Automatic
    Drag.supportedActions: Qt.CopyAction
    Drag.proposedAction: Qt.CopyAction
    Drag.mimeData: ({ "text/uri-list": U.uriList(fileDrag.path) })
    Drag.imageSource: fileDrag.image
    Drag.hotSpot.x: 24
    Drag.hotSpot.y: 24

    HoverHandler {
        onHoveredChanged: if (hovered) fileDrag.prepare()
    }

    DragHandler {
        id: handler
        target: null
        enabled: fileDrag.uri !== ""
        cursorShape: Qt.DragCopyCursor
    }
}
