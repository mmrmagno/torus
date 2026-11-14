import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services

Item {
    id: lib

    property var clips: []
    property bool loaded: false
    property string game: ""
    property bool starredOnly: false
    property string filter: ""
    property string armed: ""
    property int budget: 0
    property var favs: ({})
    readonly property real total: clips.reduce((a, c) => a + c.size, 0)
    readonly property var games: {
        const seen = {}
        const out = []
        for (const c of clips)
            if (!seen[c.game]) {
                seen[c.game] = true
                out.push({ id: c.game, name: c.name })
            }
        return out
    }
    property string sort: "new"
    property bool managing: false
    property var marks: ({})
    readonly property int markCount: Object.keys(marks).length
    property bool renaming: false
    property string renameText: ""
    property string renameError: ""
    property string look: ""
    readonly property bool busy: renaming || managing || look !== ""
    readonly property var shown: {
        const words = filter.toLowerCase()
        const out = clips.filter(c => (game === "" || c.game === game) && (!starredOnly || isFav(c)) && (words === "" || c.name.toLowerCase().includes(words) || c.path.split("/").pop().toLowerCase().includes(words)))
        return sort === "size" ? out.slice().sort((a, b) => b.size - a.size) : out
    }
    property string keptClip: ""
    property bool placing: false
    onVisibleChanged: if (!visible) leave()

    function keep() {
        if (loaded && !placing)
            keptClip = current ? current.path : ""
    }

    function forget() {
        game = ""
        starredOnly = false
        sort = "new"
        keptClip = ""
    }

    function place() {
        placing = false
        if (game !== "" && !clips.some(c => c.game === game))
            game = ""
        grid.currentIndex = Math.max(0, shown.findIndex(c => c.path === keptClip))
    }

    function leave() {
        managing = false
        marks = ({})
        renaming = false
        renameError = ""
        armed = ""
        look = ""
    }

    function mark(c) {
        if (!c)
            return
        if (isFav(c)) {
            Store.sound("error")
            return
        }
        const m = Object.assign({}, marks)
        if (m[c.path])
            delete m[c.path]
        else
            m[c.path] = true
        marks = m
        armed = ""
    }

    function trashMarked() {
        const paths = Object.keys(marks).filter(p => !clips.some(c => c.path === p && isFav(c)))
        if (paths.length === 0)
            return
        if (armed !== "marked") {
            armed = "marked"
            return
        }
        armed = ""
        const keep = grid.currentIndex
        clips = clips.filter(c => paths.indexOf(c.path) < 0)
        marks = ({})
        Store.trashMany(paths)
        grid.currentIndex = Math.max(0, Math.min(keep, shown.length - 1))
    }

    property var healed: ({})

    function thumbLost(path) {
        if (healed[path])
            return
        const h = Object.assign({}, healed)
        h[path] = true
        healed = h
        clips = clips.map(c => c.path === path ? Object.assign({}, c, { thumb: "" }) : c)
        if (!thumber.running)
            thumber.running = true
    }

    function startRename(c) {
        if (!c)
            return
        renameText = c.path.split("/").pop().replace(/\.[^.]+$/, "")
        renameError = ""
        renaming = true
    }

    function commitRename() {
        const c = current
        if (!c || renamer.running)
            return
        renamer.from = c.path
        renamer.command = ["torus-play", "rename", c.path, renameText]
        renamer.running = true
    }
    readonly property var current: shown[grid.currentIndex] || null
    signal cutRequested(string path)
    Binding {
        target: Store
        property: "clipsInfo"
        value: lib.sort + "|" + lib.managing + "|" + lib.markCount + "|" + lib.renaming + "|" + (lib.current ? lib.current.path.split("/").pop() : "") + "|" + (lib.shown.length > 0 ? lib.shown[0].path.split("/").pop() : "")
    }

    Connections {
        target: Store
        function onRestored() {
            if (lib.visible)
                lib.reload()
        }
    }

    function reload() {
        if (!lister.running)
            lister.running = true
        if (!budgetProc.running)
            budgetProc.running = true
    }

    function setBudget(v) {
        budget = v
        Quickshell.execDetached(["torus-play", "budget", String(v)])
    }

    function isFav(c) {
        return favs[c.path] !== undefined ? favs[c.path] : c.fav
    }

    function star() {
        const c = current
        if (!c)
            return
        Store.sound("tick")
        const on = !isFav(c)
        const f = Object.assign({}, favs)
        f[c.path] = on
        favs = f
        if (on && marks[c.path]) {
            const m = Object.assign({}, marks)
            delete m[c.path]
            marks = m
        }
        Quickshell.execDetached(["torus-play", "fav", c.path, on ? "on" : "off"])
    }

    function trash() {
        const c = current
        if (!c)
            return
        if (isFav(c)) {
            Store.sound("error")
            return
        }
        if (armed !== c.path) {
            armed = c.path
            return
        }
        armed = ""
        const keep = grid.currentIndex
        clips = clips.filter(x => x.path !== c.path)
        Store.trash(c.path)
        grid.currentIndex = Math.min(keep, shown.length - 1)
    }

    function play(c) {
        if (c)
            Quickshell.execDetached(["torus-launch", "xdg-open", c.path])
    }

    function step(dx, dy) {
        const cols = Math.max(1, Math.floor(grid.width / grid.cellWidth))
        grid.currentIndex = Math.max(0, Math.min(shown.length - 1, grid.currentIndex + dx + dy * cols))
        armed = ""
    }

    function key(event) {
        const ctrl = event.modifiers & Qt.ControlModifier
        if (renaming) {
            if (event.key === Qt.Key_Escape) {
                renaming = false
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                commitRename()
            } else if (event.key === Qt.Key_Backspace) {
                renameText = renameText.slice(0, -1)
            } else if (event.text.length === 1 && event.text >= " " && event.text !== "/" && !ctrl) {
                renameText += event.text
            }
            renameError = ""
            return true
        }
        if (look !== "") {
            if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) step(-1, 0)
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) step(1, 0)
            look = (event.key === Qt.Key_Space || event.key === Qt.Key_Escape || !current) ? "" : current.path
            return true
        }
        if (!managing && filter === "" && event.key === Qt.Key_Space && current) {
            look = current.path
            return true
        }
        if (managing && event.key === Qt.Key_Escape) {
            leave()
            return true
        }
        if (managing && event.key === Qt.Key_Space) {
            mark(current)
            return true
        }
        if (managing && event.key === Qt.Key_Delete && markCount > 0) {
            trashMarked()
            return true
        }
        if (event.key === Qt.Key_M && ctrl) {
            if (managing)
                leave()
            else
                managing = true
        } else if (event.key === Qt.Key_F2 || (event.key === Qt.Key_R && ctrl)) startRename(current)
        else if (event.key === Qt.Key_O && ctrl) { sort = sort === "new" ? "size" : "new"; grid.currentIndex = 0 }
        else if (event.key === Qt.Key_Right) step(1, 0)
        else if (event.key === Qt.Key_Left) step(-1, 0)
        else if (event.key === Qt.Key_Down) step(0, 1)
        else if (event.key === Qt.Key_Up) step(0, -1)
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) play(current)
        else if (event.key === Qt.Key_E && ctrl) { if (current) lib.cutRequested(current.path) }
        else if (event.key === Qt.Key_S && ctrl) star()
        else if (event.key === Qt.Key_Delete) trash()
        else if (event.key === Qt.Key_F && ctrl) starredOnly = !starredOnly
        else if (event.key === Qt.Key_Z && ctrl) Island.trashUndo()
        else if (event.key === Qt.Key_BracketRight || event.key === Qt.Key_BracketLeft) {
            const ids = [""].concat(games.map(g => g.id))
            const i = ids.indexOf(game)
            game = ids[(i + (event.key === Qt.Key_BracketRight ? 1 : -1) + ids.length) % ids.length]
            grid.currentIndex = 0
        } else
            return false
        return true
    }

    Process {
        id: renamer
        property string from: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const to = text.trim()
                if (to === "")
                    return
                const was = lib.favs[renamer.from]
                lib.clips = lib.clips.map(c => c.path === renamer.from ? Object.assign({}, c, { path: to, thumb: "" }) : c)
                if (was !== undefined) {
                    const f = Object.assign({}, lib.favs)
                    f[to] = was
                    lib.favs = f
                }
                lib.renaming = false
                lib.reload()
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") lib.renameError = text.trim() }
    }

    Process {
        id: lister
        command: ["torus-play", "library"]
        stdout: StdioCollector {
            onStreamFinished: {
                lib.favs = ({})
                lib.clips = text.split("\n").filter(l => l).map(l => {
                    const f = l.split("\t")
                    return { path: f[0], at: Number(f[1]) || 0, thumb: f[2] || "", size: Number(f[3]) || 0, auto: f[4] || "", game: f[5] || "", name: f[6] || "", fav: f[7] === "1" }
                })
                lib.loaded = true
                if (lib.placing)
                    lib.place()
                if (lib.clips.some(c => c.thumb === "") && !thumber.running)
                    thumber.running = true
            }
        }
    }

    Process {
        id: budgetProc
        command: ["torus-play", "budget"]
        stdout: StdioCollector { onStreamFinished: lib.budget = Number(text.trim()) || 0 }
    }

    Process {
        id: thumber
        command: ["torus-play", "thumbs"]
        stdout: StdioCollector { onStreamFinished: if (Number(text.trim()) > 0) lib.reload() }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.sp5

        Flow {
            Layout.fillWidth: true
            spacing: Theme.sp3
            Repeater {
                model: [{ id: "", name: "All games" }].concat(lib.games)
                Rectangle {
                    id: chip
                    required property var modelData
                    readonly property bool on: lib.game === modelData.id
                    width: chipText.implicitWidth + 20
                    height: 26
                    radius: 13
                    color: on ? Theme.accent : (chipHover.hovered ? Theme.surface1 : Theme.surface0)
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                    Text { id: chipText; anchors.centerIn: parent; text: chip.modelData.name; color: chip.on ? Theme.crust : Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm }
                    HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: { lib.placing = false; lib.game = chip.modelData.id; grid.currentIndex = 0 } }
                }
            }
            Rectangle {
                width: starText.implicitWidth + 20
                height: 26
                radius: 13
                color: lib.starredOnly ? Theme.yellow : (starHover.hovered ? Theme.surface1 : Theme.surface0)
                Text { id: starText; anchors.centerIn: parent; text: "★ Favorites"; color: lib.starredOnly ? Theme.crust : Theme.yellow; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm }
                HoverHandler { id: starHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: { lib.placing = false; lib.starredOnly = !lib.starredOnly; grid.currentIndex = 0 } }
            }
            Segmented {
                options: ["new", "size"]
                labels: ["Newest", "Biggest"]
                current: lib.sort
                activeFocusOnTab: false
                onPicked: value => { lib.sort = value; grid.currentIndex = 0 }
            }
        }

        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 230)))
            cellHeight: Math.round((cellWidth - 12) * 0.62) + 46
            model: lib.shown
            highlightMoveDuration: 120
            boundsBehavior: Flickable.StopAtBounds
            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                width: grid.cellWidth
                height: grid.cellHeight
                CaptureTile {
                    id: tile
                    anchors.fill: parent
                    anchors.margins: 6
                    path: cell.modelData.path
                    kind: "video"
                    thumb: cell.modelData.thumb
                    time: cell.modelData.at
                    bytes: cell.modelData.size
                    badge: cell.modelData.auto
                    starred: lib.isFav(cell.modelData)
                    starrable: true
                    cuttable: true
                    renamable: true
                    caption: cell.modelData.path.split("/").pop().startsWith(cell.modelData.game + "-") ? cell.modelData.name : cell.modelData.path.split("/").pop().replace(/\.[^.]+$/, "")
                    selected: cell.index === grid.currentIndex
                    marked: lib.marks[cell.modelData.path] === true
                    armed: lib.armed === cell.modelData.path || (lib.armed === "marked" && lib.marks[cell.modelData.path] === true)
                    onThumbLost: lib.thumbLost(cell.modelData.path)
                    onOpened: {
                        lib.placing = false
                        grid.currentIndex = cell.index
                        if (lib.managing)
                            lib.mark(cell.modelData)
                        else
                            lib.play(cell.modelData)
                    }
                    onAct: what => {
                        lib.placing = false
                        grid.currentIndex = cell.index
                        if (what === "rename") {
                            lib.startRename(cell.modelData)
                        } else if (what === "disarm") {
                            if (lib.armed === cell.modelData.path)
                                lib.armed = ""
                        } else if (what === "cut") {
                            lib.cutRequested(cell.modelData.path)
                        } else if (what === "folder") {
                            Quickshell.execDetached(["torus-launch", "xdg-open", cell.modelData.path.substring(0, cell.modelData.path.lastIndexOf("/"))])
                        } else if (what === "copy") {
                            Quickshell.execDetached(["sh", "-c", "printf 'file://%s\\n' \"$1\" | wl-copy --type text/uri-list", "sh", cell.modelData.path])
                        } else if (what === "delete") {
                            lib.trash()
                        } else if (what === "star") {
                            lib.star()
                        }
                    }
                }
            }

            CardState {
                anchors.fill: parent
                status: lib.shown.length > 0 ? "ready" : (!lib.loaded ? "loading" : "empty")
                text: lib.clips.length === 0 ? "No clips yet: SUPER+ALT+R saves the replay buffer while you play" : (lib.starredOnly ? "No favorites here yet: Ctrl+S makes one" : "Nothing matches")
            }
        }

        RowLayout {
            visible: lib.renaming
            Layout.fillWidth: true
            spacing: Theme.sp4
            Text { text: "Rename"; color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 28
                radius: Theme.rSm
                color: Theme.surface0
                border.width: 1
                border.color: lib.renameError !== "" ? Theme.red : Theme.accent
                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: Text.AlignVCenter
                    text: lib.renameText + "▏"
                    color: Theme.text
                    elide: Text.ElideLeft
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsMd
                }
            }
            Text { visible: lib.renameError !== ""; text: lib.renameError; color: Theme.red; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm }
            KeyHints { hints: [["↵", "save"], ["Esc", "cancel"]] }
        }

        RowLayout {
            visible: !lib.renaming
            Layout.fillWidth: true
            spacing: Theme.sp5
            KeyHints {
                Layout.fillWidth: true
                hints: lib.managing ? [["Space", "select"], ["Del", lib.armed === "marked" ? "again to trash " + lib.markCount : "trash " + lib.markCount], ["Ctrl M / Esc", "done"]]
                    : [["↵", "play"], ["Space", "look"], ["Ctrl E", "edit"], ["F2", "rename"], ["Ctrl S", "favorite"], ["Del", "trash"], ["Tab", "games"]]
            }
            PanelButton {
                icon: "󰒅"
                label: lib.managing ? "Done" : "Select"
                implicitHeight: 26
                active: lib.managing
                activeFocusOnTab: false
                onClicked: lib.managing ? lib.leave() : (lib.managing = true)
            }
            PanelButton {
                visible: lib.managing && lib.markCount > 0
                icon: "󰆴"
                label: lib.armed === "marked" ? "Trash " + lib.markCount + "? Again" : "Trash " + lib.markCount
                implicitHeight: 26
                activeFocusOnTab: false
                onClicked: lib.trashMarked()
            }
            Text { text: lib.shown.length + " of " + lib.clips.length; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm }
        }
    }

    QuickLook {
        anchors.fill: parent
        z: 20
        path: lib.look
        kind: "video"
        onClosed: lib.look = ""
    }
}
