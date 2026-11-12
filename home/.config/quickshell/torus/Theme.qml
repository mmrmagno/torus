pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var c: ({})
    readonly property string fontUi: "Inter"
    readonly property string fontMono: "JetBrainsMono Nerd Font"
    readonly property int fontSize: Math.round(12 * Feel.textScale)
    readonly property int radius: 10
    readonly property int gap: 6

    readonly property int fsXs: Math.round(10 * Feel.textScale)
    readonly property int fsSm: Math.round(11 * Feel.textScale)
    readonly property int fsMd: Math.round(12 * Feel.textScale)
    readonly property int fsBase: Math.round(13 * Feel.textScale)
    readonly property int fsLg: Math.round(14 * Feel.textScale)
    readonly property int fsXl: Math.round(16 * Feel.textScale)
    readonly property int fsTitle: Math.round(18 * Feel.textScale)
    readonly property int fsHead: Math.round(26 * Feel.textScale)
    readonly property int fsDisplay: Math.round(56 * Feel.textScale)
    readonly property int icon: 15

    readonly property int sp1: 2
    readonly property int sp2: 4
    readonly property int sp3: 6
    readonly property int sp4: 8
    readonly property int sp5: 10
    readonly property int sp6: 12
    readonly property int sp7: 16

    readonly property int rXs: 3
    readonly property int rSm: Math.round(8 * Feel.radius)
    readonly property int rCard: Math.round(12 * Feel.radius)
    readonly property int rPanel: Math.round(18 * Feel.radius)

    readonly property int track: 6
    readonly property int knob: 14

    property string animPreset: "fancy"
    readonly property real motion: animPreset === "off" || Feel.reduceMotion ? 0 : (animPreset === "snappy" ? 0.7 : 1) / Feel.speed
    readonly property int durFast: Math.round(140 * motion)
    readonly property int durMed: Math.round(200 * motion)
    readonly property int durSlow: Math.round(320 * motion)
    readonly property string flavour: c.flavour || "mocha"
    readonly property bool dark: c.dark !== false
    readonly property color shadow: c.shadow || "#cc11111b"
    function glassy(a) {
        return Math.max(0.3, Math.min(1, 1 - (1 - a) * Feel.glass))
    }
    readonly property real glassPill: glassy(dark ? 0.62 : 0.72)
    readonly property real glass: glassy(dark ? 0.7 : 0.8)
    readonly property real glassCard: glassy(dark ? 0.76 : 0.86)

    // used until qs-colors.json loads, so nothing ever renders in a placeholder color (a lock screen once could)
    readonly property var fallback: ({"rosewater": "#f5e0dc", "flamingo": "#f2cdcd", "pink": "#f5c2e7", "mauve": "#cba6f7", "red": "#f38ba8", "maroon": "#eba0ac", "peach": "#fab387", "yellow": "#f9e2af", "green": "#a6e3a1", "teal": "#94e2d5", "sky": "#89dceb", "sapphire": "#74c7ec", "blue": "#89b4fa", "lavender": "#b4befe", "text": "#cdd6f4", "subtext1": "#bac2de", "subtext0": "#a6adc8", "overlay2": "#9399b2", "overlay1": "#7f849c", "overlay0": "#6c7086", "surface2": "#585b70", "surface1": "#45475a", "surface0": "#313244", "base": "#1e1e2e", "mantle": "#181825", "crust": "#11111b", "accent": "#cba6f7"})

    function col(name) {
        return c[name] || fallback[name] || fallback.text
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
