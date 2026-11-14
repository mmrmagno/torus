import QtQuick
import QtQuick.Layouts
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs
import qs.components

Rectangle {
    id: cutter

    MouseArea {
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onWheel: wheel => wheel.accepted = true
    }

    property string path: ""
    property real duration: 0
    property var keys: []
    property var frames: []
    property real inAt: 0
    property real outAt: 0
    property bool playingSel: false
    property string status: ""
    property bool keepArmed: false
    signal closed()
    signal saved(string path)

    readonly property real pos: video.position / 1000
    readonly property real snapped: {
        let best = 0
        for (const k of keys)
            if (k <= inAt + 0.001)
                best = k
        return best
    }

    function open(p) {
        path = p
        duration = 0
        keys = []
        frames = []
        inAt = 0
        outAt = 0
        status = "reading the clip…"
        keepArmed = false
        info.command = ["torus-clipcut", "info", p]
        info.running = true
        forceActiveFocus()
    }

    function close() {
        video.stop()
        path = ""
        cutter.closed()
    }

    function fmt(t) {
        const s = Math.max(0, t)
        return Math.floor(s / 60) + ":" + (s % 60).toFixed(1).padStart(4, "0")
    }

    function seek(t) {
        video.position = Math.round(Math.max(0, Math.min(duration, t)) * 1000)
    }

    function setIn() {
        inAt = Math.min(pos, outAt - 0.5)
        keepArmed = false
    }

    function setOut() {
        outAt = Math.max(pos, inAt + 0.5)
        keepArmed = false
    }

    function playSelection() {
        if (playingSel || video.playbackState === MediaPlayer.PlayingState) {
            video.pause()
            playingSel = false
            return
        }
        seek(inAt)
        playingSel = true
        video.play()
    }

    function save(keepOnly) {
        if (cut.running || duration <= 0)
            return
        if (keepOnly && !keepArmed) {
            keepArmed = true
            status = "Ctrl+Enter again replaces the original with this part (the original goes to the trash)"
            return
        }
        keepArmed = false
        video.pause()
        status = "saving…"
        cut.command = ["torus-clipcut", "cut", path, inAt.toFixed(3), outAt.toFixed(3)].concat(keepOnly ? ["--keep-only"] : [])
        cut.running = true
    }

    color: Theme.base
    radius: Theme.rPanel
    border.width: 1
    border.color: Qt.alpha(Theme.accent, 0.35)
    focus: visible

    Keys.onPressed: event => {
        const fine = event.modifiers & Qt.ShiftModifier ? 5 : 1
        if (event.key === Qt.Key_Escape)
            cutter.close()
        else if (event.key === Qt.Key_BracketLeft)
            cutter.setIn()
        else if (event.key === Qt.Key_BracketRight)
            cutter.setOut()
        else if (event.key === Qt.Key_Space)
            cutter.playSelection()
        else if (event.key === Qt.Key_Left)
            cutter.seek(cutter.pos - fine)
        else if (event.key === Qt.Key_Right)
            cutter.seek(cutter.pos + fine)
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            cutter.save(event.modifiers & Qt.ControlModifier)
        else
            return
        event.accepted = true
    }

    Process {
        id: info
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text)
                    cutter.duration = j.duration
                    cutter.keys = j.keyframes
                    cutter.frames = j.strip
                    cutter.inAt = 0
                    cutter.outAt = j.duration
                    cutter.status = ""
                } catch (e) {
                    cutter.status = "could not read this clip"
                }
            }
        }
    }

    Process {
        id: cut
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text)
                    cutter.status = (j.replaced ? "replaced the original with " : "saved ") + cutter.fmt(j.duration) + (j.replaced ? "" : " as " + j.path.split("/").pop())
                    Store.sound("shot")
                    cutter.saved(j.path)
                    if (j.replaced) {
                        const msg = cutter.status
                        cutter.path = ""
                        Qt.callLater(() => {
                            cutter.open(j.path)
                            cutter.status = msg
                        })
                    }
                } catch (e) {}
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") cutter.status = text.trim().replace(/^torus-clipcut: /, "")
        }
    }

    MediaPlayer {
        id: video
        source: cutter.path !== "" ? "file://" + cutter.path : ""
        videoOutput: screen
        audioOutput: AudioOutput {}
        property bool primed: false
        onMediaStatusChanged: if (mediaStatus === MediaPlayer.LoadedMedia && !primed) {
            primed = true
            play()
            pause()
        }
        onSourceChanged: primed = false
        onPositionChanged: if (cutter.playingSel && video.position / 1000 >= cutter.outAt) {
            pause()
            cutter.playingSel = false
            cutter.seek(cutter.outAt)
        }
        onPlaybackStateChanged: if (playbackState !== MediaPlayer.PlayingState) cutter.playingSel = false
    }

    readonly property bool playing: video.playbackState === MediaPlayer.PlayingState
    readonly property string title: {
        const parts = path.split("/")
        const dir = parts.length > 1 ? parts[parts.length - 2] : ""
        return dir.split("-").map(w => w ? w[0].toUpperCase() + w.slice(1) : w).join(" ")
    }
    readonly property string when: {
        const m = path.match(/(\d{4})-(\d{2})-(\d{2})-(\d{2})(\d{2})\d{2}/)
        return m ? Qt.formatDateTime(new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5]), "d MMM, HH:mm") : ""
    }

    function togglePlay() {
        playingSel = false
        if (playing)
            video.pause()
        else
            video.play()
        forceActiveFocus()
    }

    RowLayout {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.sp7
        spacing: Theme.sp5
        Text { text: "󰕧"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: Theme.fsTitle }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text { Layout.fillWidth: true; text: cutter.title !== "" ? cutter.title : "Clip"; color: Theme.text; elide: Text.ElideRight; font.family: Theme.fontUi; font.pixelSize: Theme.fsXl; font.weight: Font.DemiBold }
            Text { Layout.fillWidth: true; text: [cutter.when, cutter.duration > 0 ? cutter.fmt(cutter.duration) + " long" : ""].filter(x => x).join("  ·  "); color: Theme.overlay; elide: Text.ElideRight; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm }
        }
        Rectangle {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            radius: 15
            color: closeHover.hovered ? Theme.surface1 : Theme.surface0
            Text { anchors.centerIn: parent; text: "󰅖"; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fsMd }
            HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: cutter.close() }
        }
    }

    Rectangle {
        id: stage
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: transport.top
        anchors.leftMargin: Theme.sp7
        anchors.rightMargin: Theme.sp7
        anchors.topMargin: Theme.sp6
        anchors.bottomMargin: Theme.sp5
        radius: Theme.rCard
        color: Theme.crust

        VideoOutput {
            id: screen
            anchors.fill: stage
            anchors.margins: 2
            fillMode: VideoOutput.PreserveAspectFit
        }
        Rectangle {
            visible: cutter.duration > 0 && !cutter.playing
            anchors.centerIn: stage
            width: 64
            height: 64
            radius: 32
            color: Qt.alpha(Theme.crust, 0.7)
            border.width: 1
            border.color: Qt.alpha(Theme.text, 0.2)
            Text { anchors.centerIn: parent; anchors.horizontalCenterOffset: 3; text: "󰐊"; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: 30 }
        }
        TapHandler { onTapped: if (cutter.duration > 0) cutter.togglePlay() }
        HoverHandler { cursorShape: Qt.PointingHandCursor }

        CardState {
            anchors.fill: stage
            status: cutter.duration > 0 ? "ready" : (cutter.status === "reading the clip…" ? "loading" : "error")
            text: cutter.status
            retryable: false
        }
    }

    RowLayout {
        id: transport
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: strip.top
        anchors.leftMargin: Theme.sp7
        anchors.rightMargin: Theme.sp7
        anchors.bottomMargin: Theme.sp5
        spacing: Theme.sp5
        Rectangle {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: 16
            color: playHover.hovered ? Theme.accent : Theme.surface0
            Behavior on color { ColorAnimation { duration: Theme.durFast } }
            Text { anchors.centerIn: parent; anchors.horizontalCenterOffset: cutter.playing ? 0 : 1; text: cutter.playing ? "󰏤" : "󰐊"; color: playHover.hovered ? Theme.crust : Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fsXl }
            HoverHandler { id: playHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: cutter.togglePlay() }
        }
        Text {
            text: cutter.fmt(cutter.pos) + "  /  " + cutter.fmt(cutter.duration)
            color: Theme.text
            font.family: Theme.fontMono
            font.pixelSize: Theme.fsSm
        }
        Item { Layout.fillWidth: true }
        Text {
            Layout.maximumWidth: 520
            text: cutter.status !== "" && cutter.duration > 0 ? cutter.status : ("part " + cutter.fmt(cutter.inAt) + " → " + cutter.fmt(cutter.outAt) + "  ·  " + (cutter.outAt - cutter.snapped).toFixed(1) + " s" + (cutter.snapped < cutter.inAt - 0.05 ? "  ·  starts on the keyframe at " + cutter.fmt(cutter.snapped) : ""))
            color: cutter.keepArmed ? Theme.red : Theme.subtext
            elide: Text.ElideLeft
            font.family: Theme.fontMono
            font.pixelSize: Theme.fsSm
        }
    }

    Item {
        id: strip
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.leftMargin: Theme.sp7 + 6
        anchors.rightMargin: Theme.sp7 + 6
        anchors.bottomMargin: Theme.sp6
        height: 64
        readonly property real k: cutter.duration > 0 ? width / cutter.duration : 0
        readonly property real x1: cutter.inAt * k
        readonly property real x2: cutter.outAt * k

        ClippingRectangle {
            anchors.fill: strip
            radius: Theme.rSm
            color: Theme.surface0
            Row {
                anchors.fill: parent
                Repeater {
                    model: cutter.frames
                    Image {
                        required property string modelData
                        width: strip.width / Math.max(1, cutter.frames.length)
                        height: strip.height
                        source: "file://" + modelData
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }
            }
            Rectangle { x: 0; width: strip.x1; height: strip.height; color: Qt.alpha(Theme.crust, 0.72) }
            Rectangle { x: strip.x2; width: Math.max(0, strip.width - strip.x2); height: strip.height; color: Qt.alpha(Theme.crust, 0.72) }
        }
        Rectangle {
            x: strip.x1
            width: Math.max(2, strip.x2 - strip.x1)
            height: strip.height
            color: "transparent"
            border.width: 2
            border.color: Theme.accent
            radius: Theme.rSm
        }
        Rectangle {
            visible: cutter.snapped < cutter.inAt - 0.05
            x: cutter.snapped * strip.k
            width: 2
            height: strip.height
            color: Theme.peach
        }
        Repeater {
            model: cutter.keys
            Rectangle {
                required property real modelData
                x: modelData * strip.k
                y: strip.height - 5
                width: 1
                height: 5
                color: Qt.alpha(Theme.text, 0.5)
            }
        }
        MouseArea {
            anchors.fill: parent
            property real from: 0
            cursorShape: Qt.PointingHandCursor
            function at(x) { return Math.max(0, Math.min(cutter.duration, x / Math.max(1, strip.k))) }
            onPressed: mouse => { from = at(mouse.x); cutter.seek(from) }
            onPositionChanged: mouse => {
                if (!pressed)
                    return
                const t = at(mouse.x)
                if (Math.abs(t - from) > 0.3) {
                    cutter.inAt = Math.min(from, t)
                    cutter.outAt = Math.max(from, t)
                    cutter.keepArmed = false
                }
                cutter.seek(t)
            }
            onReleased: cutter.forceActiveFocus()
        }
        Rectangle {
            id: inHandle
            x: strip.x1 - width / 2
            y: -6
            width: 12
            height: strip.height + 12
            radius: 4
            color: inArea.containsMouse || inArea.pressed ? Theme.text : Theme.accent
            Rectangle { anchors.centerIn: parent; width: 2; height: 18; radius: 1; color: Theme.crust }
            MouseArea {
                id: inArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.SizeHorCursor
                onPositionChanged: mouse => {
                    if (!pressed)
                        return
                    const t = mapToItem(strip, mouse.x, 0).x / Math.max(1, strip.k)
                    cutter.inAt = Math.max(0, Math.min(cutter.outAt - 0.5, t))
                    cutter.keepArmed = false
                    cutter.seek(cutter.inAt)
                }
                onReleased: cutter.forceActiveFocus()
            }
        }
        Rectangle {
            id: outHandle
            x: strip.x2 - width / 2
            y: -6
            width: 12
            height: strip.height + 12
            radius: 4
            color: outArea.containsMouse || outArea.pressed ? Theme.text : Theme.accent
            Rectangle { anchors.centerIn: parent; width: 2; height: 18; radius: 1; color: Theme.crust }
            MouseArea {
                id: outArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.SizeHorCursor
                onPositionChanged: mouse => {
                    if (!pressed)
                        return
                    const t = mapToItem(strip, mouse.x, 0).x / Math.max(1, strip.k)
                    cutter.outAt = Math.min(cutter.duration, Math.max(cutter.inAt + 0.5, t))
                    cutter.keepArmed = false
                    cutter.seek(cutter.outAt)
                }
                onReleased: cutter.forceActiveFocus()
            }
        }
        Rectangle {
            x: cutter.pos * strip.k - 1
            y: -4
            z: 5
            width: 2
            height: strip.height + 8
            color: Theme.text
        }
    }

    RowLayout {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.sp7
        spacing: Theme.sp5
        KeyHints {
            Layout.fillWidth: true
            hints: [["[ / ]", "in / out"], ["Space", "play part"], ["← / →", "seek"], ["Esc", "back"]]
        }
        PanelButton {
            icon: "󰆓"
            label: "Save copy  ↵"
            active: true
            activeFocusOnTab: false
            onClicked: cutter.save(false)
        }
        PanelButton {
            icon: "󰩹"
            label: cutter.keepArmed ? "Sure? Click again" : "Keep only this  Ctrl ↵"
            activeFocusOnTab: false
            active: cutter.keepArmed
            onClicked: {
                cutter.save(true)
                cutter.forceActiveFocus()
            }
        }
    }
}
