pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var c: ({})
    readonly property string fontUi: "Inter"
    readonly property string fontMono: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 12
    readonly property int radius: 10
    readonly property int gap: 6
    readonly property real glassPill: 0.62
    readonly property real glass: 0.7
    readonly property real glassCard: 0.76

    function col(name) {
        return c[name] || "#ff00ff"
    }

    readonly property color accent: col("accent")
    readonly property color text: col("text")
    readonly property color subtext: col("subtext0")
    readonly property color overlay: col("overlay0")
    readonly property color base: col("base")
    readonly property color mantle: col("mantle")
    readonly property color crust: col("crust")
    readonly property color surface0: col("surface0")
    readonly property color surface1: col("surface1")
    readonly property color red: col("red")
    readonly property color green: col("green")
    readonly property color yellow: col("yellow")
    readonly property color peach: col("peach")
    readonly property color blue: col("blue")
    readonly property color mauve: col("mauve")
    readonly property color lavender: col("lavender")
    readonly property color teal: col("teal")
    readonly property color sapphire: col("sapphire")

    function reload() {
        file.reload()
    }

    FileView {
        id: file
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/torus/theme/qs-colors.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.c = JSON.parse(text())
            } catch (e) {
                console.warn("torus: bad qs-colors.json", e)
            }
        }
    }
}
