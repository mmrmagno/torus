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

    readonly property int fsXs: 10
    readonly property int fsSm: 11
    readonly property int fsMd: 12
    readonly property int fsBase: 13
    readonly property int fsLg: 14
    readonly property int fsXl: 16
    readonly property int fsTitle: 18
    readonly property int fsHead: 26
    readonly property int fsDisplay: 56
    readonly property int icon: 15

    readonly property int sp1: 2
    readonly property int sp2: 4
    readonly property int sp3: 6
    readonly property int sp4: 8
    readonly property int sp5: 10
    readonly property int sp6: 12
    readonly property int sp7: 16

    readonly property int rXs: 3
    readonly property int rSm: 8
    readonly property int rCard: 12
    readonly property int rPanel: 18

    readonly property int track: 6
    readonly property int knob: 14

    property string animPreset: "fancy"
    readonly property real motion: animPreset === "off" ? 0 : (animPreset === "snappy" ? 0.7 : 1)
    readonly property int durFast: Math.round(140 * motion)
    readonly property int durMed: Math.round(200 * motion)
    readonly property int durSlow: Math.round(320 * motion)
    readonly property string flavour: c.flavour || "mocha"
    readonly property bool dark: c.dark !== false
    readonly property color shadow: c.shadow || "#cc11111b"
    readonly property real glassPill: dark ? 0.62 : 0.72
    readonly property real glass: dark ? 0.7 : 0.8
    readonly property real glassCard: dark ? 0.76 : 0.86

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
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/torus/animations"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.animPreset = text().trim() || "fancy"
        onLoadFailed: root.animPreset = "fancy"
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
