import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services

Rectangle {
    id: dock

    property var game: null
    property string mode: "grid"
    property int clipIndex: 0
    property int settingIndex: 0
    property string armed: ""
    readonly property var rows: [
        { key: "overlay", label: "Overlay", values: ["keep", "on", "off"] },
        { key: "power", label: "Power profile", values: ["performance", "balanced", "keep"] },
        { key: "replay", label: "Replay buffer", values: ["on", "off"] },
        { key: "replay_secs", label: "Buffer length", values: [30, 60, 120] },
        { key: "hold", label: "Hold notifications", values: ["on", "off"] },
        { key: "gamescope", label: "Gamescope wrapper", values: ["off", "on"] }
    ]
    readonly property var recap: game && Play.last.appid === game.id ? Play.last : null

    function step(d) {
        if (mode === "clips")
            clipIndex = Math.max(0, Math.min(Play.clips.length - 1, clipIndex + d))
        else if (mode === "settings")
            settingIndex = Math.max(0, Math.min(rows.length - 1, settingIndex + d))
    }

    function cycle(d) {
        if (mode !== "settings" || !game)
            return
        const r = rows[settingIndex]
        const cur = Play.shown[r.key]
        const i = r.values.indexOf(cur)
        const v = r.values[(Math.max(0, i) + d + r.values.length) % r.values.length]
        Play.set(game.id, r.key, v)
        if (r.key === "gamescope" && v === "on")
            Quickshell.execDetached(["sh", "-c", "printf %s 'gamescope -f -- %command%' | wl-copy && notify-send -a torus 'Gamescope launch option copied' 'Paste it into Steam: the game > Properties > Launch options'"])
    }

    function clip() {
        return Play.clips[clipIndex] || null
    }

    function play() {
        const c = clip()
        if (c)
            Quickshell.execDetached(["torus-launch", "xdg-open", c.path])
    }

    function remove() {
        const c = clip()
        if (!c)
            return
        Store.sound("delete")
        Quickshell.execDetached(["gio", "trash", c.path])
        Play.clips = Play.clips.filter(x => x.path !== c.path)
        clipIndex = Math.max(0, Math.min(clipIndex, Play.clips.length - 1))
    }

    function copy() {
        const c = clip()
        if (!c)
            return
        Quickshell.execDetached(["sh", "-c", "printf 'file://%s\\n' \"$1\" | wl-copy -t text/uri-list", "sh", c.path])
        Quickshell.execDetached(["notify-send", "-a", "torus", "-u", "low", "Copied", c.path.split("/").pop()])
    }

    onGameChanged: {
        clipIndex = 0
        if (game)
            Play.load(game.id)
    }

    Layout.fillWidth: true
    implicitHeight: 186
    radius: Theme.rCard
    color: Qt.alpha(Theme.surface0, 0.55)
    border.width: 1
    border.color: dock.mode === "grid" ? Qt.alpha(Theme.surface1, 0.6) : Qt.alpha(Theme.accent, 0.6)

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: Theme.sp6

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: dock.mode !== "settings"
            spacing: Theme.sp3

            Text {
                text: dock.recap ? "Last session: " + dock.recap.minutes + " min" + (dock.recap.fps_avg ? "  ·  " + dock.recap.fps_avg + " FPS, 1 % low " + dock.recap.fps_low1 : "") + (dock.recap.gpu_temp_max ? "  ·  GPU max " + dock.recap.gpu_temp_max + " °C" : "")
                    : (Play.clips.length > 0 ? "Clips" : "No clips yet: SUPER+ALT+R saves the replay buffer while you play")
                color: Theme.subtext
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsSm
            }

            ListView {
                id: strip
                Layout.fillWidth: true
                Layout.fillHeight: true
                orientation: ListView.Horizontal
                spacing: Theme.sp4
                clip: true
                model: Play.clips
                currentIndex: dock.clipIndex
                highlightMoveDuration: 120
                delegate: CaptureTile {
                    id: shot
                    required property var modelData
                    required property int index
                    height: strip.height
                    width: Math.round((height - 34) / 0.62)
                    path: shot.modelData.path
                    kind: "video"
                    thumb: shot.modelData.thumb
                    time: shot.modelData.at
                    bytes: shot.modelData.size
                    selected: dock.mode === "clips" && shot.index === dock.clipIndex
                    armed: dock.armed === shot.modelData.path
                    onOpened: {
                        dock.mode = "clips"
                        dock.clipIndex = shot.index
                        dock.play()
                    }
                    onAct: what => {
                        dock.clipIndex = shot.index
                        if (what === "disarm") {
                            if (dock.armed === shot.modelData.path)
                                dock.armed = ""
                        } else if (what === "copy") {
                            dock.copy()
                        } else if (what === "folder") {
                            Quickshell.execDetached(["torus-launch", "xdg-open", shot.modelData.path.substring(0, shot.modelData.path.lastIndexOf("/"))])
                        } else if (what === "delete") {
                            if (dock.armed !== shot.modelData.path) {
                                dock.armed = shot.modelData.path
                                return
                            }
                            dock.armed = ""
                            dock.remove()
                        }
                    }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            visible: dock.mode === "settings"
            columns: 3
            rowSpacing: 1
            columnSpacing: Theme.sp6
            Repeater {
                model: dock.rows
                Text {
                    required property var modelData
                    required property int index
                    Layout.row: index % 3
                    Layout.column: Math.floor(index / 3)
                    Layout.fillWidth: true
                    text: (index === dock.settingIndex ? "▸ " : "   ") + modelData.label + ":  " + (Play.shown[modelData.key] !== undefined ? Play.shown[modelData.key] : "…") + (modelData.key === "replay_secs" ? " s" : "")
                    color: index === dock.settingIndex ? Theme.accent : Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsBase
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignTop
            text: dock.mode === "settings" ? "↑↓ pick  ←→ change\nTab back" : dock.mode === "clips" ? "Enter plays  Del trashes\nCtrl+C copies  Tab settings" : "Tab: clips, then settings"
            color: Theme.overlay
            horizontalAlignment: Text.AlignRight
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsXs
        }
    }
}
