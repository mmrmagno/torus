import QtQuick
import Quickshell
import qs
import qs.services

Item {
    id: view

    property bool live: true
    property bool throttle: false
    property bool living: false
    readonly property real load: Math.max(0, Math.min(1, SysStats.cpu / 100))
    property real spin: living ? 0.6 + 1.6 * load : 1
    Behavior on spin { NumberAnimation { duration: 1500; easing.type: Easing.InOutSine } }
    property real kick: 0
    property real peakKick: 0
    property real peakBank: 0
    onBankChanged: if (Math.abs(bank) > peakBank) peakBank = Math.abs(bank)
    onKickChanged: if (kick > peakKick) peakKick = kick
    property real bank: 0
    property int lastNotifs: 0
    Component.onCompleted: lastNotifs = Store.notifCount
    property int lastWs: 0
    readonly property bool calm: living && load < 0.06
    property string shape: "torus"
    readonly property int gridW: shape === "xwing" ? DonutClock.w * 2 : DonutClock.w
    readonly property int gridH: shape === "xwing" ? DonutClock.h * 2 : DonutClock.h
    property real cellH: 16
    property real t: 0
    property real acc: 0
    property int skip: 0
    readonly property real cellW: Math.round(cellH * 0.6)
    readonly property string shaderDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/torus/shaders/"
    signal frame

    Connections {
        target: Store
        enabled: view.living
        function onNotifCountChanged() {
            if (Store.notifCount > view.lastNotifs)
                wobble.restart()
            view.lastNotifs = Store.notifCount
        }
    }

    property int workspaceId: 0
    onWorkspaceIdChanged: {
        if (living && shape === "xwing" && lastWs > 0 && workspaceId > 0 && workspaceId !== lastWs) {
            bankDir = workspaceId > lastWs ? 1 : -1
            bankAnim.restart()
        }
        lastWs = workspaceId
    }
    property int bankDir: 1

    NumberAnimation { id: wobble; target: view; property: "kick"; from: 1; to: 0; duration: 900; easing.type: Easing.OutCubic }

    SequentialAnimation {
        id: bankAnim
        NumberAnimation { target: view; property: "bank"; to: 9 * view.bankDir; duration: 260; easing.type: Easing.OutCubic }
        NumberAnimation { target: view; property: "bank"; to: 0; duration: 700; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
    }

    rotation: view.bank
    property real breath: 0
    scale: 1 + breath * 0.018
    SequentialAnimation on breath {
        running: view.calm && view.live && view.visible
        loops: Animation.Infinite
        NumberAnimation { from: 0; to: 1; duration: 3200; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1; to: 0; duration: 3200; easing.type: Easing.InOutSine }
    }
    onCalmChanged: if (!calm) breath = 0

    implicitWidth: cellW * gridW
    implicitHeight: cellH * gridH

    FrameAnimation {
        id: anim
        running: view.live && view.visible
        onTriggered: {
            view.acc += frameTime
            const rate = smoothFrameTime > 0 ? 1 / smoothFrameTime : 60
            if (++view.skip < Math.max(1, Math.round(rate / (view.throttle ? 30 : 60))))
                return
            view.skip = 0
            view.t += Math.min(view.acc, 0.1) * (1 + Visualizer.bass * 1.6) * view.spin
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
        width: view.gridW
        height: view.gridH
        property point grid: Qt.point(view.gridW, view.gridH)
        property point ab: Qt.point((1 + view.t * DonutClock.speedA + view.kick * 0.5 * Math.sin(view.t * 30)) % (2 * Math.PI), (1 + view.t * DonutClock.speedB + view.kick * 0.35 * Math.cos(view.t * 26)) % (2 * Math.PI))
        fragmentShader: "file://" + view.shaderDir + view.shape + ".frag.qsb"
    }

    ShaderEffectSource {
        id: levelTex
        sourceItem: levelPass
        hideSource: true
        smooth: false
        textureSize: Qt.size(view.gridW, view.gridH)
        width: view.gridW
        height: view.gridH
        visible: false
    }

    ShaderEffect {
        anchors.fill: parent
        property variant levels: levelTex
        property variant atlas: atlasTex
        property point grid: Qt.point(view.gridW, view.gridH)
        property real boost: Theme.dark ? 1 + Visualizer.bass * 0.45 : 1 - Visualizer.bass * 0.3
        fragmentShader: "file://" + view.shaderDir + "donut.frag.qsb"
    }
}
