import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services

PanelWindow {
    id: win

    readonly property bool fullscreen: screen ? Fullscreen.isFull(screen.name) : false
    readonly property bool shown: Store.wallpaper === "donut"
    readonly property bool live: shown && !fullscreen && !Store.gamemode && !Store.donutPaused
    readonly property real cellH: screen ? Math.max(8, Math.round(Math.min(screen.width, screen.height) * 0.5 / DonutClock.h)) : 16
    readonly property real cellW: Math.round(cellH * 0.6)
    readonly property string shaderPath: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/torus/shaders/donut.frag.qsb"
    property int frames: 0
    property string frozen: ""

    visible: shown
    implicitWidth: cellW * DonutClock.w
    implicitHeight: cellH * DonutClock.h
    exclusiveZone: -1
    color: "transparent"
    mask: Region {}
    WlrLayershell.namespace: "torus-donut"
    WlrLayershell.layer: WlrLayer.Bottom

    onLiveChanged: {
        DonutClock.consumers += live ? 1 : -1
        if (!live)
            frozen = DonutClock.url
    }
    Component.onCompleted: if (live) DonutClock.consumers += 1
    Component.onDestruction: if (live) DonutClock.consumers -= 1

    Connections {
        target: DonutClock
        enabled: win.live
        function onUrlChanged() {
            win.frames++
            Store.reportFrames(win.screen.name, win.frames)
        }
    }

    Row {
        id: atlas
        Repeater {
            model: 12
            Item {
                required property int index
                width: win.cellW
                height: win.cellH
                Text {
                    anchors.centerIn: parent
                    text: DonutClock.chars[parent.index]
                    color: DonutClock.colors[parent.index] || Theme.accent
                    font.family: Theme.fontMono
                    font.pixelSize: Math.max(6, Math.round(win.cellH * 0.82)) | 0
                }
            }
        }
    }

    ShaderEffectSource {
        id: atlasTex
        sourceItem: atlas
        hideSource: true
        textureSize: Qt.size(Math.max(1, atlas.width), Math.max(1, atlas.height))
        width: atlas.width
        height: atlas.height
        visible: false
    }

    Image {
        id: levelTex
        visible: false
        smooth: false
        cache: true
        source: win.live ? DonutClock.url : (win.frozen || DonutClock.url)
    }

    ShaderEffect {
        anchors.fill: parent
        property variant levels: levelTex
        property variant atlas: atlasTex
        property point grid: Qt.point(DonutClock.w, DonutClock.h)
        fragmentShader: "file://" + win.shaderPath
    }
}
