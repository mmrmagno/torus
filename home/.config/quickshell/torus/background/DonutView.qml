import QtQuick
import Quickshell
import qs
import qs.services

Item {
    id: view

    property bool live: true
    property real cellH: 16
    readonly property real cellW: Math.round(cellH * 0.6)
    readonly property string shaderPath: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/torus/shaders/donut.frag.qsb"
    property string frozen: ""
    signal frame

    implicitWidth: cellW * DonutClock.w
    implicitHeight: cellH * DonutClock.h

    onLiveChanged: {
        DonutClock.consumers += live ? 1 : -1
        if (!live)
            frozen = DonutClock.url
    }
    Component.onCompleted: if (live) DonutClock.consumers += 1
    Component.onDestruction: if (live) DonutClock.consumers -= 1

    Connections {
        target: DonutClock
        enabled: view.live
        function onUrlChanged() {
            view.frame()
        }
    }

    Row {
        id: atlas
        Repeater {
            model: 12
            Item {
                required property int index
                width: view.cellW
                height: view.cellH
                Text {
                    anchors.centerIn: parent
                    text: DonutClock.chars[parent.index]
                    color: DonutClock.colors[parent.index] || Theme.accent
                    font.family: Theme.fontMono
                    font.pixelSize: Math.max(6, Math.round(view.cellH * 0.82)) | 0
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
        source: view.live ? DonutClock.url : (view.frozen || DonutClock.url)
    }

    ShaderEffect {
        anchors.fill: parent
        property variant levels: levelTex
        property variant atlas: atlasTex
        property point grid: Qt.point(DonutClock.w, DonutClock.h)
        property real boost: 1 + Visualizer.bass * 0.45
        fragmentShader: "file://" + view.shaderPath
    }
}
