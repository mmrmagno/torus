import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.components
import qs.background
import qs.services

PanelWindow {
    id: root

    readonly property var flavours: ["mocha", "macchiato", "frappe", "latte"]
    readonly property var accents: ["rosewater", "flamingo", "pink", "mauve", "red", "maroon", "peach", "yellow", "green", "teal", "sky", "sapphire", "blue", "lavender"]
    property var palettes: ({})
    readonly property string flavour: Theme.c.flavour || "mocha"
    readonly property string accentName: Theme.c.accentName || "mauve"
    readonly property var pal: palettes[flavour] || Theme.c
    property string anim: Theme.animPreset
    property string busy: ""
    property string hoverAccent: ""
    property string wallScreen: ""

    function cap(s) {
        return s.charAt(0).toUpperCase() + s.slice(1)
    }

    function run(what, args) {
        if (worker.running)
            return
        busy = what
        worker.command = args
        worker.running = true
    }

    function setAnim(name) {
        anim = name
        Quickshell.execDetached(["sh", "-c", "echo \"$2\" | torus-reload write \"$1/animations\"", "sh", Store.stateDir, name])
    }

    screen: Store.screenFor("theme")
    anchors.top: true
    margins.top: Store.barGap
    visible: Store.isOpen("theme") || motion.leaving
    onVisibleChanged: {
        if (!visible)
            return
        if (!loader.running)
            loader.running = true
        Qt.callLater(() => {
            const target = Store.themeSection === "wallpaper" ? wallHeading : (Store.themeSection === "feel" ? feelHeading : null)
            flick.contentY = target ? Math.max(0, Math.min(target.y - 8, flick.contentHeight - flick.height)) : 0
        })
    }
    implicitWidth: Math.min(760, (screen ? screen.width : 800) - 40)
    implicitHeight: Math.min((screen ? screen.height : 900) - Store.barGap - 20, body.implicitHeight + 40)
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "torus-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Store.isOpen("theme") && !Store.moving ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    HyprlandFocusGrab {
        active: Store.isOpen("theme")
        windows: [root]
        onCleared: Store.setOpen("theme", false)
    }

    Process {
        id: loader
        command: ["sh", "-c", "r=$(dirname \"$(readlink -f \"$(command -v torus)\")\")/../../..; for f in mocha macchiato frappe latte; do [ -f \"$r/theme/$f.json\" ] && printf '%s\\t%s\\n' \"$f\" \"$(tr -d '\\n' < \"$r/theme/$f.json\")\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = {}
                for (const line of text.split("\n")) {
                    const i = line.indexOf("\t")
                    if (i < 0)
                        continue
                    try {
                        p[line.slice(0, i)] = JSON.parse(line.slice(i + 1))
                    } catch (e) {}
                }
                root.palettes = p
            }
        }
    }

    Process {
        id: worker
        onExited: root.busy = ""
    }

    Rectangle {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Store.setOpen("theme", false)
        PanelMotion {
            id: motion
            target: parent
            shown: Store.isOpen("theme") && !Store.moving
        }
        radius: Theme.rPanel
        color: Qt.alpha(Theme.base, Theme.glassCard)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.35)
        clip: true

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: 20
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: body
                width: parent.width
                spacing: Theme.sp6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.sp5
                    Text { text: "󰏘"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 22 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text { text: "Theme"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsTitle; font.weight: Font.DemiBold }
                        Text {
                            text: root.busy !== "" ? "Applying " + root.busy + " everywhere…" : "Shell, apps, terminal and login screen follow these choices"
                            color: root.busy !== "" ? Theme.accent : Theme.overlay
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fsSm
                        }
                    }
                }

                Heading { text: "Flavor" }

                GridLayout {
                    Layout.fillWidth: true
                    columns: root.width > 620 ? 4 : 2
                    columnSpacing: Theme.sp5
                    rowSpacing: Theme.sp5

                    Repeater {
                        model: root.flavours
                        FlavourCard {
                            required property string modelData
                            name: modelData
                            p: root.palettes[modelData] || ({})
                        }
                    }
                }

                Heading { text: "Accent  ·  " + (root.hoverAccent || root.accentName) }

                Flow {
                    Layout.fillWidth: true
                    spacing: Theme.sp4
                    Repeater {
                        model: root.accents
                        Item {
                            id: dot
                            required property string modelData
                            readonly property bool on: modelData === root.accentName
                            width: 34
                            height: 34
                            Rectangle {
                                anchors.centerIn: parent
                                width: 34
                                height: 34
                                radius: 17
                                color: "transparent"
                                border.width: dot.on ? 2 : 0
                                border.color: root.pal[dot.modelData] || Theme.accent
                            }
                            Rectangle {
                                anchors.centerIn: parent
                                width: dot.on ? 22 : (dotHover.hovered ? 30 : 26)
                                height: width
                                radius: width / 2
                                color: root.pal[dot.modelData] || Theme.col(dot.modelData)
                                Behavior on width { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutBack } }
                            }
                            HoverHandler {
                                id: dotHover
                                cursorShape: Qt.PointingHandCursor
                                onHoveredChanged: root.hoverAccent = hovered ? dot.modelData : (root.hoverAccent === dot.modelData ? "" : root.hoverAccent)
                            }
                            TapHandler { onTapped: root.run(dot.modelData, ["torus", "accent", dot.modelData]) }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Heading { id: wallHeading; text: "Wallpaper" }
                    Item { Layout.fillWidth: true }
                    Segmented {
                        visible: Quickshell.screens.length > 1
                        options: [""].concat(Quickshell.screens.map(s => s.name))
                        labels: ["All screens"].concat(Quickshell.screens.map(s => s.name + (s.height > s.width ? " (portrait)" : "")))
                        current: root.wallScreen
                        onPicked: value => root.wallScreen = value
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: Theme.sp5
                    Repeater {
                        model: Store.wallpapers
                        Rectangle {
                            id: wall
                            required property string modelData
                            readonly property bool on: modelData === (root.wallScreen === "" ? Store.wallpaper : Store.wallFor(root.wallScreen))
                            readonly property bool still: modelData.startsWith("still:")
                            readonly property string shape: modelData === "xwing" ? "xwing" : "torus"
                            width: 208
                            height: 117
                            radius: Theme.rCard
                            border.width: on ? 2 : 1
                            border.color: on ? Theme.accent : (wallHover.hovered ? Theme.surface1 : Qt.alpha(Theme.surface1, 0.5))
                            gradient: Gradient {
                                GradientStop { position: 0; color: Theme.base }
                                GradientStop { position: 1; color: Theme.mantle }
                            }
                            scale: wallHover.hovered && !on ? 1.03 : 1
                            Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
                            clip: true
                            Image {
                                visible: wall.still
                                anchors.fill: parent
                                anchors.margins: 2
                                source: wall.still ? "file://" + wall.modelData.slice(6) : ""
                                sourceSize: Qt.size(416, 234)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                            Loader {
                                active: !wall.still && root.visible
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: 1
                                sourceComponent: DonutView {
                                    shape: wall.shape
                                    live: root.visible
                                    throttle: true
                                    cellH: Math.max(2, 84 / gridH)
                                    width: implicitWidth
                                    height: implicitHeight
                                }
                            }
                            Text {
                                visible: !wall.still
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 6
                                text: "marc @ os"
                                color: Theme.overlay
                                font.family: Theme.fontMono
                                font.pixelSize: 7
                            }
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.leftMargin: 8
                                anchors.topMargin: 8
                                width: nameText.implicitWidth + 14
                                height: 18
                                radius: 9
                                color: wall.on ? Theme.accent : Qt.alpha(Theme.crust, 0.7)
                                Text {
                                    id: nameText
                                    anchors.centerIn: parent
                                    text: wall.still ? wall.modelData.split("/").pop().replace(/\.[^.]+$/, "").slice(0, 22) : (wall.modelData === "donut" ? "Donut" : "X-wing")
                                    color: wall.on ? Theme.crust : Theme.text
                                    font.family: Theme.fontUi
                                    font.pixelSize: Theme.fsXs
                                    font.weight: wall.on ? Font.DemiBold : Font.Normal
                                }
                            }
                            HoverHandler { id: wallHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: Store.setWallpaperFor(root.wallScreen, wall.modelData) }
                        }
                    }
                    Rectangle {
                        width: 208
                        height: 117
                        radius: Theme.rCard
                        color: addHover.hovered ? Qt.alpha(Theme.accent, 0.08) : "transparent"
                        border.width: 1
                        border.color: addHover.hovered ? Theme.accent : Theme.surface1
                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.sp2
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰸉"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 22 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Add pictures"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "~/Pictures/wallpapers"; color: Theme.overlay; font.family: Theme.fontMono; font.pixelSize: Theme.fsXs }
                        }
                        HoverHandler { id: addHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: Quickshell.execDetached(["sh", "-c", "mkdir -p \"$HOME/Pictures/wallpapers\" && xdg-open \"$HOME/Pictures/wallpapers\""]) }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.sp4
                    Text { text: "Living donut"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd }
                    Text { Layout.fillWidth: true; text: "color drifts with the time of day and the album art"; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; elide: Text.ElideRight }
                    Toggle { checked: Store.livingDonut; onToggled: value => Store.setLivingDonut(value) }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.sp4
                    Text { text: "Match accent"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd }
                    Text { Layout.fillWidth: true; text: "picking a picture sets the closest accent color"; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; elide: Text.ElideRight }
                    Toggle { checked: Store.matchAccent; onToggled: value => Store.setMatchAccent(value) }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.sp4
                    Text { text: "Breathing"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd }
                    Text { Layout.fillWidth: true; text: "pictures softly blur and breathe while a workspace is empty"; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; elide: Text.ElideRight }
                    Toggle { checked: Store.breathing; onToggled: value => Store.setBreathing(value) }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.sp4
                    Text { text: "Slideshow"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd }
                    Text { Layout.fillWidth: true; text: Slideshow.on && Slideshow.paused ? "paused while locked or in a fullscreen app" : "changes the wallpaper on its own"; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; elide: Text.ElideRight }
                    PanelButton { visible: Slideshow.on; label: "Next"; icon: "󰒭"; implicitHeight: 28; onClicked: Slideshow.next() }
                    Toggle { checked: Slideshow.on; onToggled: value => Slideshow.set({ on: value }) }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: Slideshow.on
                    spacing: Theme.sp4
                    Segmented {
                        options: Slideshow.choices.map(String)
                        labels: ["5 min", "15 min", "30 min", "1 h", "3 h", "daily"]
                        current: String(Slideshow.minutes)
                        onPicked: value => Slideshow.set({ minutes: Number(value) })
                    }
                    Item { Layout.fillWidth: true }
                    Text { text: "Shuffle"; color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm }
                    Toggle { checked: Slideshow.shuffle; onToggled: value => Slideshow.set({ shuffle: value }) }
                    Text { text: "Donut & X-wing"; color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm }
                    Toggle { checked: Slideshow.shaders; onToggled: value => Slideshow.set({ shaders: value }) }
                    Text { text: "Per screen"; color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm }
                    Toggle { checked: Slideshow.perScreen; onToggled: value => Slideshow.set({ perScreen: value }) }
                }

                Heading { id: feelHeading; text: "Feel" }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: Theme.sp6
                    rowSpacing: Theme.sp5

                    Text { text: "Animations"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd }
                    Segmented {
                        options: ["fancy", "smooth", "snappy", "off"]
                        labels: ["Fancy", "Smooth", "Snappy", "Off"]
                        current: root.anim
                        onPicked: value => root.setAnim(value)
                    }
                    Text { text: "Bar"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd }
                    Segmented {
                        options: ["full", "compact", "hidden"]
                        labels: ["Full", "Compact", "Hidden"]
                        current: Store.barHidden ? "hidden" : Store.barPreset
                        onPicked: value => {
                            if (value === "hidden") {
                                Store.barHidden = true
                            } else {
                                Store.barHidden = false
                                Store.setBarPreset(value)
                            }
                        }
                    }
                    Text { text: "Night light"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd }
                    RowLayout {
                        spacing: Theme.sp4
                        Toggle { checked: NightLight.auto; onToggled: value => NightLight.setAuto(value) }
                        Text { text: "at sunset " + NightLight.sunset + ", off at sunrise " + NightLight.sunrise; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm }
                    }
                    Text { text: "Desktop widgets"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd }
                    Segmented {
                        options: Store.widgetModes
                        labels: ["Landscape screens", "All screens", "Off"]
                        current: Store.widgets
                        onPicked: value => Store.setWidgets(value)
                    }
                }
            }
        }
    }

    component Heading: Text {
        color: Theme.overlay
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsSm
        font.letterSpacing: 1.2
        font.capitalization: Font.AllUppercase
        Layout.topMargin: Theme.sp2
    }

    component FlavourCard: Rectangle {
        id: card
        property string name
        property var p: ({})
        readonly property bool on: name === root.flavour
        readonly property bool light: name === "latte"
        Layout.fillWidth: true
        Layout.preferredHeight: 112
        radius: Theme.rCard
        color: p.base || Theme.base
        border.width: on ? 2 : 1
        border.color: on ? Theme.accent : (cardHover.hovered ? Theme.surface1 : Qt.alpha(Theme.surface1, 0.6))
        scale: cardHover.hovered && !on ? 1.02 : 1
        Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }

        Rectangle {
            x: 10
            y: 10
            width: parent.width - 20
            height: 56
            radius: 8
            color: card.p.mantle || Theme.mantle
            Row {
                x: 8
                y: 8
                spacing: 4
                Repeater {
                    model: ["red", "yellow", "green"]
                    Rectangle { required property string modelData; width: 6; height: 6; radius: 3; color: card.p[modelData] || Theme.col(modelData) }
                }
            }
            Column {
                x: 8
                y: 22
                spacing: 5
                Rectangle { width: 60; height: 5; radius: 2; color: card.p[root.accentName] || Theme.accent }
                Rectangle { width: 86; height: 5; radius: 2; color: card.p.text || Theme.text; opacity: 0.8 }
                Rectangle { width: 44; height: 5; radius: 2; color: card.p.subtext0 || Theme.subtext; opacity: 0.7 }
            }
            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 8
                width: 22
                height: 22
                radius: 11
                color: card.p[root.accentName] || Theme.accent
            }
        }

        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 10
            spacing: 6
            Text {
                Layout.fillWidth: true
                text: root.cap(card.name)
                color: card.p.text || Theme.text
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsMd
                font.weight: Font.DemiBold
            }
            Text {
                text: card.on ? "󰄬" : (card.light ? "󰖨" : "󰖔")
                color: card.on ? (card.p[root.accentName] || Theme.accent) : (card.p.overlay0 || Theme.overlay)
                font.family: Theme.fontMono
                font.pixelSize: Theme.fsLg
            }
        }

        HoverHandler { id: cardHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: if (!card.on) root.run(root.cap(card.name), ["torus", "flavour", card.name]) }
    }
}
