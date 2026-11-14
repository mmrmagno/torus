import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.components
import qs.services

Rectangle {
    id: sheet

    property var game: null
    property int index: 0
    signal closed()

    readonly property bool cs2: game !== null && game.id === "730"
    readonly property var playing: [
        { key: "overlay", label: "FPS overlay", note: "MangoHud in the corner", values: ["keep", "on", "off"], labels: ["As is", "On", "Off"] },
        { key: "power", label: "Power profile", note: "while the game runs", values: ["performance", "balanced", "keep"], labels: ["Performance", "Balanced", "As is"] },
        { key: "hold", label: "Hold notifications", note: "shown after you stop playing", values: ["off", "on"] },
        { key: "gamescope", label: "Gamescope", note: "turning it on copies the Steam launch option", values: ["off", "on"] }
    ]
    readonly property var recording: [
        { key: "replay", label: "Replay buffer", note: "SUPER+ALT+R saves the last seconds", values: ["off", "on"] },
        { key: "replay_secs", label: "Buffer length", note: "how far back a clip reaches", values: ["30", "60", "120"], labels: ["30 s", "60 s", "2 min"] },
        { key: "clip_audio", label: "Clip audio", note: "what a clip records", values: ["everything", "game + mic", "game"], labels: ["Everything", "Game + mic", "Game only"] }
    ]
    readonly property var highlights: cs2 ? [
        { key: "highlights", label: "Auto highlights", note: "saves a clip on these moments", values: ["off", "on"] },
        { key: "hl_ace", label: "Ace", note: "all 5 kills in a round", values: ["off", "on"], sub: true },
        { key: "hl_4k", label: "4 kills", note: "in one round", values: ["off", "on"], sub: true },
        { key: "hl_3k", label: "3 kills", note: "in one round", values: ["off", "on"], sub: true },
        { key: "hl_clutch", label: "Clutch", note: "round won, you alive, 2+ kills", values: ["off", "on"], sub: true }
    ] : []
    readonly property var rows: playing.concat(recording).concat(highlights)
    readonly property var recap: game && Play.last.appid === game.id ? Play.last : null

    function value(key) {
        const v = Play.shown[key]
        return v === undefined ? "" : String(v)
    }

    function set(key, v) {
        if (!game || value(key) === v)
            return
        Store.sound("tick")
        Play.set(game.id, key, key === "replay_secs" ? Number(v) : v)
        if (key === "gamescope" && v === "on")
            Quickshell.execDetached(["sh", "-c", "printf %s 'gamescope -f -- %command%' | wl-copy && notify-send -a torus 'Gamescope launch option copied' 'Paste it into Steam: the game > Properties > Launch options'"])
    }

    function change(d) {
        const r = rows[index]
        if (!r)
            return
        const i = Math.max(0, r.values.indexOf(value(r.key)))
        set(r.key, r.values[Math.max(0, Math.min(r.values.length - 1, i + d))])
    }

    function flip() {
        const r = rows[index]
        if (r && r.values.length === 2)
            set(r.key, value(r.key) === "on" ? "off" : "on")
        else
            change(1)
    }

    function open(g) {
        game = g
        index = 0
        if (g && Play.shownId !== String(g.id))
            Play.load(g.id)
    }

    function key(event) {
        if (event.key === Qt.Key_Escape)
            sheet.closed()
        else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab)
            index = Math.min(rows.length - 1, index + 1)
        else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab)
            index = Math.max(0, index - 1)
        else if (event.key === Qt.Key_Left)
            change(-1)
        else if (event.key === Qt.Key_Right)
            change(1)
        else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            flip()
        return true
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onWheel: wheel => wheel.accepted = true
    }

    radius: Theme.rPanel
    color: Theme.base
    border.width: 1
    border.color: Qt.alpha(Theme.accent, 0.35)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 22
        spacing: Theme.sp6

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp6
            ClippingRectangle {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 72
                radius: Theme.rSm
                color: Theme.surface0
                Image {
                    anchors.fill: parent
                    source: sheet.game && sheet.game.art ? "file://" + sheet.game.art : ""
                    sourceSize.width: 96
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.sp2
                Text {
                    Layout.fillWidth: true
                    text: sheet.game ? sheet.game.name : ""
                    color: Theme.text
                    elide: Text.ElideRight
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsTitle
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    text: sheet.recap ? "Last session: " + (sheet.recap.match ? sheet.recap.match.map + " " + sheet.recap.match.score + ", " + sheet.recap.match.kills + "/" + sheet.recap.match.deaths + " K/D  ·  " : "") + sheet.recap.minutes + " min" + (sheet.recap.fps_avg ? "  ·  " + sheet.recap.fps_avg + " FPS, 1 % low " + sheet.recap.fps_low1 : "") + (sheet.recap.gpu_temp_max ? "  ·  GPU max " + sheet.recap.gpu_temp_max + " °C" : "") : "Settings apply the next time the game starts"
                    color: Theme.subtext
                    elide: Text.ElideRight
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsSm
                }
            }
            Rectangle {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 15
                color: closeHover.hovered ? Theme.surface1 : Theme.surface0
                Text { anchors.centerIn: parent; text: "󰅖"; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fsMd }
                HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: sheet.closed() }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.sp7 + Theme.sp4

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                spacing: Theme.sp2
                Text { text: "While playing"; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; font.letterSpacing: 1.2; font.capitalization: Font.AllUppercase; Layout.bottomMargin: Theme.sp2 }
                Repeater {
                    model: sheet.playing
                    GameSettingRow {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        owner: sheet
                        row: modelData
                        rowIndex: index
                    }
                }
                Text { text: "Recording"; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; font.letterSpacing: 1.2; font.capitalization: Font.AllUppercase; Layout.topMargin: Theme.sp6; Layout.bottomMargin: Theme.sp2 }
                Repeater {
                    model: sheet.recording
                    GameSettingRow {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        owner: sheet
                        row: modelData
                        rowIndex: sheet.playing.length + index
                    }
                }
            }

            ColumnLayout {
                visible: sheet.cs2
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                spacing: Theme.sp2
                Text { text: "Auto highlights"; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; font.letterSpacing: 1.2; font.capitalization: Font.AllUppercase; Layout.bottomMargin: Theme.sp2 }
                Repeater {
                    model: sheet.highlights
                    GameSettingRow {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        owner: sheet
                        row: modelData
                        rowIndex: sheet.playing.length + sheet.recording.length + index
                    }
                }
            }
        }

        KeyHints {
            Layout.fillWidth: true
            hints: [["↑ / ↓", "pick"], ["← / →", "change"], ["Space", "switch"], ["Esc", "back"]]
        }
    }
}
