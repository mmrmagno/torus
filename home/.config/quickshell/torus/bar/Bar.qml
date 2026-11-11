import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.components

PanelWindow {
    id: bar

    readonly property bool compact: Store.barPreset === "compact"
    readonly property bool narrow: screen && screen.width < 1400
    readonly property var groups: ({
        left: [["cpu", "memory", "cpuinfo", "gpuinfo"], ["idle", "clock"], ["workspaces", "taskbar"]],
        narrow: [["media"]],
        right: [["privacy", "updates", "clipboard", "tray", "notifications"], ["sunset", "backlight", "network", "audio", "mic", "battery", "power"], ["menu"]]
    })
    property var loaders: []
    property var shown: ({})

    function setShown(mid, value) {
        if (shown[mid] === value)
            return
        const s = Object.assign({}, shown)
        s[mid] = value
        shown = s
    }

    function register() {
        const ids = []
        for (const l of loaders)
            if (l.item && l.item.available !== false)
                ids.push(l.mid)
        Store.registerModules(screen.name, ids)
    }

    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        top: compact ? 3 : 4
        left: compact ? 6 : 8
        right: compact ? 6 : 8
    }
    implicitHeight: compact ? 24 : 28
    exclusiveZone: Store.barHidden ? 0 : implicitHeight
    visible: !Store.barHidden
    color: "transparent"
    WlrLayershell.namespace: "torus-bar"
    WlrLayershell.layer: WlrLayer.Top

    component Section: Row {
        id: section
        property var spec: []
        spacing: Theme.gap
        height: bar.implicitHeight

        Repeater {
            model: section.spec

            Pill {
                id: pill
                required property var modelData
                height: bar.implicitHeight
                pad: bar.compact ? 6 : 8
                visible: modelData.some(id => bar.shown[id] === true)

                Repeater {
                    model: pill.modelData

                    Loader {
                        id: loader
                        required property string modelData
                        readonly property string mid: modelData
                        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                        source: "modules/" + modelData.charAt(0).toUpperCase() + modelData.slice(1) + ".qml"
                        readonly property bool on: item ? item.available !== false && (item.shown === undefined || item.shown) : false
                        visible: on
                        onOnChanged: bar.setShown(mid, on)
                        onLoaded: {
                            bar.setShown(mid, on)
                            bar.loaders = bar.loaders.concat([loader])
                            registerTimer.restart()
                        }
                    }
                }
            }
        }
    }

    Timer {
        id: registerTimer
        interval: 500
        onTriggered: bar.register()
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: bar.register()
    }

    Section {
        anchors.left: parent.left
        spec: bar.groups.left
    }

    Section {
        anchors.right: parent.right
        spec: bar.narrow ? bar.groups.narrow.concat(bar.groups.right) : bar.groups.right
    }
}
