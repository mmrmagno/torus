import QtQuick
import QtQuick.Controls
import "donut.mjs" as D

Rectangle {
    id: root

    readonly property color base: config.base
    readonly property color mantle: config.mantle
    readonly property color crust: config.crust
    readonly property color text: config.text
    readonly property color subtext: config.subtext
    readonly property color overlay: config.overlay
    readonly property color surface0: config.surface0
    readonly property color surface1: config.surface1
    readonly property color accent: config.accent
    readonly property color red: config.red
    readonly property var ramp: D.ramp({ mauve: String(config.mauve), lavender: String(config.lavender), base: String(config.base) })
    readonly property real side: Math.min(width, height)
    property int session: sessionModel.lastIndex
    property bool busy: false

    function login() {
        if (busy || password.text === "")
            return
        busy = true
        message.text = ""
        sddm.login(user.text, password.text, session)
    }

    width: Screen.width
    height: Screen.height
    gradient: Gradient {
        GradientStop { position: 0; color: root.base }
        GradientStop { position: 1; color: root.crust }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false
            password.text = ""
            message.text = "Wrong password"
            shake.restart()
            password.forceActiveFocus()
        }
        function onLoginSucceeded() {
            message.text = ""
        }
    }

    Repeater {
        id: users
        model: userModel
        Item {
            required property string name
            readonly property string login: name
        }
    }

    Repeater {
        id: sessions
        model: sessionModel
        Item {
            required property string name
            readonly property string label: name
        }
    }

    Item {
        id: donut

        property real t: 0
        readonly property real cellH: Math.max(8, Math.round(root.side * 0.42 / D.H))
        readonly property real cellW: Math.round(cellH * 0.6)

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: column.top
        anchors.bottomMargin: root.side * 0.02
        width: cellW * D.W
        height: cellH * D.H

        FrameAnimation {
            running: true
            onTriggered: donut.t += Math.min(frameTime, 0.1)
        }

        Row {
            id: atlas
            Repeater {
                model: 12
                Item {
                    required property int index
                    width: donut.cellW
                    height: donut.cellH
                    Text {
                        anchors.centerIn: parent
                        text: D.CHARS[parent.index]
                        color: root.ramp[parent.index]
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Math.max(6, Math.round(donut.cellH * 0.82))
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
            width: D.W
            height: D.H
            property point grid: Qt.point(D.W, D.H)
            property point ab: Qt.point((1 + donut.t * 1.68) % (2 * Math.PI), (1 + donut.t * 0.72) % (2 * Math.PI))
            fragmentShader: Qt.resolvedUrl("torus.frag.qsb")
        }

        ShaderEffectSource {
            id: levelTex
            sourceItem: levelPass
            hideSource: true
            smooth: false
            textureSize: Qt.size(D.W, D.H)
            width: D.W
            height: D.H
            visible: false
        }

        ShaderEffect {
            anchors.fill: parent
            property variant levels: levelTex
            property variant atlas: atlasTex
            property point grid: Qt.point(D.W, D.H)
            property real boost: 1
            fragmentShader: Qt.resolvedUrl("donut.frag.qsb")
        }
    }

    Column {
        id: column
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.side * 0.2
        spacing: 14
        width: Math.min(360, root.width - 64)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(clock.now, "hh:mm")
            color: root.text
            font.family: "Inter"
            font.pixelSize: Math.round(root.side * 0.07)
            font.weight: Font.Bold
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "<font color=\"" + root.accent + "\">" + user.text + "</font><font color=\"" + root.overlay + "\"> @ </font><font color=\"" + config.lavender + "\">os</font>"
            textFormat: Text.RichText
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
        }

        Rectangle {
            id: field
            width: parent.width
            height: 46
            radius: 23
            color: Qt.alpha(root.mantle, 0.92)
            border.width: 1
            border.color: message.text !== "" ? root.red : (password.activeFocus ? root.accent : root.surface1)
            Behavior on border.color { ColorAnimation { duration: 150 } }

            SequentialAnimation on anchors.horizontalCenterOffset {
                id: shake
                running: false
                NumberAnimation { to: -10; duration: 50 }
                NumberAnimation { to: 10; duration: 70 }
                NumberAnimation { to: -6; duration: 60 }
                NumberAnimation { to: 0; duration: 50 }
            }

            Text {
                id: lockIcon
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                text: root.busy ? "󰔟" : "󰌾"
                color: root.accent
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
            }

            TextInput {
                id: password
                anchors.left: lockIcon.right
                anchors.leftMargin: 12
                anchors.right: go.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                echoMode: TextInput.Password
                passwordCharacter: "●"
                color: root.text
                font.family: "Inter"
                font.pixelSize: 15
                focus: true
                clip: true
                enabled: !root.busy
                onAccepted: root.login()
                onTextChanged: if (text !== "") message.text = ""

                Text {
                    visible: password.text === ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: keyboard.capsLock ? "Password (caps lock is on)" : "Password"
                    color: keyboard.capsLock ? root.red : root.overlay
                    font: password.font
                }
            }

            Rectangle {
                id: go
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                height: 34
                radius: 17
                color: goHover.hovered ? root.accent : root.surface0
                Text {
                    anchors.centerIn: parent
                    text: "󰁔"
                    color: goHover.hovered ? root.crust : root.accent
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                }
                HoverHandler { id: goHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.login() }
            }
        }

        Text {
            id: message
            anchors.horizontalCenter: parent.horizontalCenter
            height: 16
            color: root.red
            font.family: "Inter"
            font.pixelSize: 12
        }
    }

    Row {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 24
        spacing: 10

        Rectangle {
            height: 34
            width: userRow.implicitWidth + 28
            radius: 17
            color: Qt.alpha(root.mantle, 0.85)
            Row {
                id: userRow
                anchors.centerIn: parent
                spacing: 8
                Text { text: "󰀄"; color: root.accent; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                TextInput {
                    id: user
                    anchors.verticalCenter: parent.verticalCenter
                    text: userModel.lastUser || (users.count > 0 && users.itemAt(0) ? users.itemAt(0).login : "")
                    color: root.text
                    font.family: "Inter"
                    font.pixelSize: 12
                    selectByMouse: true
                    onAccepted: password.forceActiveFocus()
                }
            }
        }

        Rectangle {
            height: 34
            width: sessionText.implicitWidth + 28
            radius: 17
            color: sessionHover.hovered ? root.surface0 : Qt.alpha(root.mantle, 0.85)
            Text {
                id: sessionText
                anchors.centerIn: parent
                text: "󰍹  " + (sessions.count > 0 && sessions.itemAt(root.session) ? sessions.itemAt(root.session).label : "session")
                color: root.text
                font.family: "Inter"
                font.pixelSize: 12
            }
            HoverHandler { id: sessionHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.session = (root.session + 1) % Math.max(1, sessions.count) }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 24
        spacing: 10

        Repeater {
            model: [
                { icon: "󰤄", act: "suspend", ok: sddm.canSuspend },
                { icon: "󰜉", act: "reboot", ok: sddm.canReboot },
                { icon: "󰐥", act: "powerOff", ok: sddm.canPowerOff }
            ]
            Rectangle {
                required property var modelData
                visible: modelData.ok
                width: 38
                height: 38
                radius: 19
                color: powerHover.hovered ? (modelData.act === "powerOff" ? root.red : root.accent) : Qt.alpha(root.mantle, 0.85)
                Text {
                    anchors.centerIn: parent
                    text: parent.modelData.icon
                    color: powerHover.hovered ? root.crust : root.subtext
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 16
                }
                HoverHandler { id: powerHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: sddm[parent.modelData.act]() }
            }
        }
    }

    Timer {
        id: clock
        property date now: new Date()
        interval: 1000
        running: true
        repeat: true
        onTriggered: now = new Date()
    }

    Component.onCompleted: password.forceActiveFocus()
}
