import QtQuick
import Quickshell
import qs
import qs.services

Item {
    id: view

    property bool live: true
    property bool throttle: false
    property real cellH: 16
    property real t: 0
    property real acc: 0
    property int skip: 0
    readonly property real cellW: Math.round(cellH * 0.6)
    readonly property string shaderDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/torus/shaders/"
    signal frame

    implicitWidth: cellW * DonutClock.w
    implicitHeight: cellH * DonutClock.h

    FrameAnimation {
        id: anim
        running: view.live && view.visible
        onTriggered: {
            view.acc += frameTime
            const rate = smoothFrameTime > 0 ? 1 / smoothFrameTime : 60
            if (++view.skip < Math.max(1, Math.round(rate / (view.throttle ? 30 : 60))))
                return
            view.skip = 0
            view.t += Math.min(view.acc, 0.1) * (1 + Visualizer.bass * 1.6)
            view.acc = 0
            DonutClock.ticks++
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

    ShaderEffect {
        id: levelPass
        width: DonutClock.w
        height: DonutClock.h
        property point grid: Qt.point(DonutClock.w, DonutClock.h)
        property point ab: Qt.point((1 + view.t * DonutClock.speedA) % (2 * Math.PI), (1 + view.t * DonutClock.speedB) % (2 * Math.PI))
        fragmentShader: "file://" + view.shaderDir + "torus.frag.qsb"
    }

    ShaderEffectSource {
        id: levelTex
        sourceItem: levelPass
        hideSource: true
        smooth: false
        textureSize: Qt.size(DonutClock.w, DonutClock.h)
        width: DonutClock.w
        height: DonutClock.h
        visible: false
    }

    ShaderEffect {
        anchors.fill: parent
        property variant levels: levelTex
        property variant atlas: atlasTex
        property point grid: Qt.point(DonutClock.w, DonutClock.h)
        property real boost: 1 + Visualizer.bass * 0.45
        fragmentShader: "file://" + view.shaderDir + "donut.frag.qsb"
    }
}
