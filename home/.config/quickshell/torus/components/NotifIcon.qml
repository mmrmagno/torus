import QtQuick
import Quickshell
import qs

Item {
    id: root

    property string image: ""
    property string appIcon: ""
    property string app: ""
    property int size: 28
    property int tried: 0

    readonly property bool mine: app.toLowerCase() === "torus"
    readonly property var candidates: {
        const out = []
        const file = p => p.startsWith("/") ? "file://" + p : (p.startsWith("image://icon//") ? "file://" + p.slice(13) : p)
        const isPath = p => p.startsWith("/") || p.startsWith("file:") || p.startsWith("image:")
        if (image)
            out.push(file(image))
        if (appIcon && isPath(appIcon))
            out.push(file(appIcon))
        else if (appIcon)
            out.push(Quickshell.iconPath(appIcon, true))
        const e = app ? DesktopEntries.heuristicLookup(app) : null
        if (e && e.icon)
            out.push(isPath(e.icon) ? file(e.icon) : Quickshell.iconPath(e.icon, true))
        return out.filter(c => c)
    }

    implicitWidth: size
    implicitHeight: size
    onCandidatesChanged: tried = 0

    Image {
        id: img
        anchors.fill: parent
        visible: !root.mine && status === Image.Ready
        source: !root.mine && root.tried < root.candidates.length ? root.candidates[root.tried] : ""
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        onStatusChanged: if (status === Image.Error) root.tried++
    }

    Rectangle {
        anchors.centerIn: parent
        visible: root.mine
        width: root.size * 0.8
        height: width
        radius: width / 2
        color: "transparent"
        border.width: Math.max(3, width * 0.26)
        border.color: Theme.accent
    }

    Text {
        anchors.centerIn: parent
        visible: !root.mine && !img.visible
        text: "󰂚"
        color: Theme.accent
        font.family: Theme.fontMono
        font.pixelSize: root.size * 0.7
    }
}
