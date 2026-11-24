import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services

PanelWindow {
    id: root

    property string view: "home"
    property string source: "all"
    property string query: ""
    property var home: ({ sections: [] })
    property var grid: []
    property var found: []
    property var detail: null
    property var stack: []
    property var notes: []
    property bool loading: false
    property bool more: false
    property string gridFor: ""
    property bool failed: false
    property string failure: ""
    property int homeSec: 0
    property int homeIdx: 0
    property var stars: ({})
    property bool setting: false
    readonly property bool covered: setting || !!menuRow
    property var menuRow: null
    property int keptRow: -1

    Connections {
        target: Music
        function onQueueReplacing() {
            root.keptRow = root.mode === "queue" ? list.currentIndex : -1
        }
        function onQueueReplaced() {
            if (root.keptRow >= 0)
                Qt.callLater(() => {
                    list.currentIndex = Math.min(root.keptRow, list.count - 1)
                    root.keptRow = -1
                })
        }
    }
    property int menuAt: -1
    readonly property string mode: detail ? "detail" : (query !== "" ? "search" : view)
    readonly property var views: ["home", "albums", "artists", "playlists", "queue"]
    readonly property var sources: ["all", "local"].concat(Music.servers.map(s => s.name))
    readonly property var listRows: mode === "search" ? found : mode === "detail" ? detail.rows : mode === "queue" ? Music.queue.map((r, i) => Object.assign({ kind: "track", group: "Up next", qi: i }, r)) : []
    readonly property var selected: {
        if (mode === "home") {
            const s = home.sections[homeSec]
            return s ? s.rows[homeIdx] || null : null
        }
        if (mode === "albums" || mode === "artists" || mode === "playlists")
            return grid[gridView.currentIndex] || null
        return listRows[list.currentIndex] || null
    }

    function key(r) {
        return r ? r.source + "\u0001" + r.kind + "\u0001" + r.id : ""
    }

    function starredOf(r) {
        const k = key(r)
        return stars[k] !== undefined ? stars[k] : !!(r && r.starred)
    }

    function setView(v) {
        detail = null
        stack = []
        query = ""
        search.text = ""
        view = v
        load()
    }

    function setSource(s) {
        source = s
        if (mode === "search")
            find(false)
        else if (!detail)
            load()
    }

    function load() {
        failed = false
        notes = []
        more = false
        if (view === "queue") {
            loading = false
            list.currentIndex = Math.max(0, Music.pos)
            return
        }
        const asked = view + "\u0001" + source
        loading = true
        if (view !== "home" && gridFor !== asked) {
            grid = []
            gridFor = asked
        }
        Music.browse([view, source], (m, changed, rest) => {
            if (root.view + "\u0001" + root.source !== asked)
                return
            const here = root.mode === root.view
            if (here) {
                root.more = rest
                root.loading = false
            }
            if (m.error && !here)
                return
            if (m.error) {
                const shown = root.view === "home" ? root.home.sections.length : root.grid.length
                root.failed = shown === 0
                root.failure = m.error
                root.notes = shown > 0 ? [m.error] : []
                return
            }
            if (here) {
                root.failed = false
                root.notes = m.notes || []
            }
            if (root.view === "home") {
                if (changed)
                    root.fillHome(m.sections || [])
            } else if (changed) {
                root.fillGrid(m.rows || [])
            }
        })
    }

    function same(a, b) {
        const plain = (k, v) => k === "cover" ? undefined : v
        return JSON.stringify(a, plain) === JSON.stringify(b, plain)
    }

    function fillHome(secs) {
        if (same(home.sections, secs))
            return
        const old = home.sections[homeSec]
        const title = old ? old.title : ""
        const at = old ? key(old.rows[homeIdx]) : ""
        const y = sections.contentY
        home = { sections: secs }
        let s = secs.findIndex(x => x.title === title)
        homeSec = s >= 0 ? s : Math.min(homeSec, Math.max(0, secs.length - 1))
        const rows = secs[homeSec] ? secs[homeSec].rows : []
        const i = rows.findIndex(r => key(r) === at)
        homeIdx = i >= 0 && homeIdx > 0 ? i : Math.max(0, Math.min(homeIdx, rows.length - 1))
        sections.forceLayout()
        sections.contentY = Math.max(0, Math.min(y, sections.contentHeight - sections.height))
    }

    function fillGrid(rows) {
        if (grid.length && same(grid, rows))
            return
        const at = key(grid[gridView.currentIndex])
        const y = gridView.contentY
        const held = grid.length > 0
        grid = rows
        const i = held && at ? rows.findIndex(r => key(r) === at) : 0
        gridView.currentIndex = Math.max(0, i)
        if (held)
            gridView.contentY = Math.max(0, Math.min(y, gridView.contentHeight - gridView.height))
    }

    function find(local) {
        if (query === "")
            return
        failed = false
        const q = query
        const src = source
        Music.browse(["search", q, local ? "local" : src], (m, changed, rest) => {
            if (root.query !== q || root.source !== src || (local && root.foundFor === q))
                return
            if (m.error) {
                if (local)
                    return
                root.loading = false
                root.more = false
                root.failed = true
                root.failure = m.error
                return
            }
            const tag = (rows, g) => rows.map(r => Object.assign({ group: g }, r))
            const rows = tag(m.tracks || [], "Songs").concat(tag(m.albums || [], "Albums"), tag(m.artists || [], "Artists"))
            if (local && rows.length === 0)
                return
            root.more = local ? true : rest
            root.loading = root.more && rows.length === 0
            root.notes = m.notes || []
            root.fillFound(rows, q)
        })
    }

    property string foundFor: ""

    function fillFound(rows, q) {
        const again = foundFor === q
        const at = again && list.currentIndex > 0 ? key(found[list.currentIndex]) : ""
        foundFor = q
        if (again && same(found, rows))
            return
        const y = list.contentY
        found = rows
        list.currentIndex = at ? Math.max(0, rows.findIndex(r => key(r) === at)) : 0
        if (again) {
            list.forceLayout()
            list.contentY = Math.max(list.originY, Math.min(y, list.originY + list.contentHeight - list.height))
        }
    }

    function open(r) {
        if (!r || r.kind === "track")
            return
        if (r.kind === "playlist" || r.kind === "album" || r.kind === "artist") {
            if (detail && detail.row !== r)
                stack = stack.concat([detail])
            detail = { row: r, head: r, rows: [], loading: true }
            loading = true
            more = false
            failed = false
            Music.browse(["open", r.kind, r.source, r.id], (m, changed, rest) => {
                if (!root.detail || root.detail.row !== r)
                    return
                root.loading = false
                root.more = rest
                if (m.error) {
                    root.failed = true
                    root.failure = m.error
                    return
                }
                if (!changed && !root.detail.loading)
                    return
                const albums = (m.albums || []).map(a => Object.assign({ group: "Albums" }, a))
                const tracks = (m.tracks || []).map(t => Object.assign({ group: r.kind === "artist" ? "Top songs" : "Songs" }, t))
                const at = root.detail.loading ? 0 : list.currentIndex
                root.detail = { row: r, head: m.head || r, rows: tracks.concat(albums) }
                list.currentIndex = Math.max(0, Math.min(at, root.detail.rows.length - 1))
            })
        }
    }

    function back() {
        if (menuRow) {
            menuRow = null
            return
        }
        if (detail) {
            detail = stack.length ? stack[stack.length - 1] : null
            stack = stack.slice(0, -1)
            failed = false
            loading = false
            more = false
            return
        }
        if (query !== "") {
            search.text = ""
            return
        }
        Store.setOpen("music", false)
    }

    function play(r, mode) {
        if (!r)
            return
        if (root.mode === "queue" && r.qi !== undefined && (!mode || mode === "play")) {
            Music.act(["jump", String(r.qi)])
            return
        }
        if (root.mode === "detail" && r.kind === "track" && detail && (detail.head.kind === "album" || detail.head.kind === "playlist") && (!mode || mode === "play")) {
            Music.act(["play", detail.head.kind, detail.head.source, detail.head.id, String(detail.rows.filter(x => x.kind === "track").indexOf(r))])
            return
        }
        Music.play(r, listRows.length ? listRows : null, mode)
        if (!mode || mode === "play")
            Island.flash("osd", { icon: "󰎆", label: "Playing " + r.title, value: -1 }, 1400)
        else
            Island.flash("osd", { icon: "󰐕", label: (mode === "next" ? "Next up: " : "Queued: ") + r.title, value: -1 }, 1400)
    }

    function star(r) {
        if (!r || r.source === "local" || r.kind === "artist" || r.kind === "playlist")
            return
        const on = !starredOf(r)
        const s = Object.assign({}, stars)
        s[key(r)] = on
        stars = s
        Music.act(["starset", r.source, r.id, on ? "1" : "0"])
    }

    function showMenu(r, x, y) {
        menuRow = r
        menu.index = 0
        const p = { x: Math.min(x, frame.width - menu.width - 12), y: Math.min(y, frame.height - menu.height - 12) }
        menu.x = Math.max(12, p.x)
        menu.y = Math.max(12, p.y)
    }

    function menuItems(r) {
        if (!r)
            return []
        const out = [["play", "󰐊", "Play", "↵"], ["next", "󰒭", "Play next", "Ctrl ↵"], ["add", "󰐕", "Add to queue", "Shift ↵"]]
        if (r.kind !== "track")
            out.push(["open", "󰈈", "Open", "Shift Space"])
        if (r.qi !== undefined)
            out.push(["remove", "󰆴", "Remove from queue", "Del"])
        if (r.source !== "local" && (r.kind === "track" || r.kind === "album"))
            out.push(["star", starredOf(r) ? "󰓎" : "󰓒", starredOf(r) ? "Unstar" : "Star", "Ctrl S"])
        return out
    }

    function choose(what) {
        const r = menuRow
        menuRow = null
        if (what === "play" || what === "next" || what === "add")
            play(r, what === "play" ? undefined : what)
        else if (what === "open")
            open(r)
        else if (what === "remove")
            Music.act(["remove", String(r.qi)])
        else if (what === "star")
            star(r)
        search.forceActiveFocus()
    }

    function moveSel(dx, dy) {
        if (mode === "home") {
            const secs = home.sections
            if (!secs.length)
                return
            if (dy !== 0) {
                homeSec = Math.max(0, Math.min(secs.length - 1, homeSec + dy))
                homeIdx = Math.min(homeIdx, secs[homeSec].rows.length - 1)
                sections.positionViewAtIndex(homeSec, ListView.Contain)
            } else {
                homeIdx = Math.max(0, Math.min(secs[homeSec].rows.length - 1, homeIdx + dx))
            }
        } else if (mode === "albums" || mode === "artists" || mode === "playlists") {
            if (dx > 0) gridView.moveCurrentIndexRight()
            else if (dx < 0) gridView.moveCurrentIndexLeft()
            else if (dy > 0) gridView.moveCurrentIndexDown()
            else if (dy < 0) gridView.moveCurrentIndexUp()
        } else if (dy !== 0) {
            list.currentIndex = Math.max(0, Math.min(list.count - 1, list.currentIndex + dy))
        }
    }

    function handle(event) {
        const ctrl = event.modifiers & Qt.ControlModifier
        const shift = event.modifiers & Qt.ShiftModifier
        const enter = event.key === Qt.Key_Return || event.key === Qt.Key_Enter
        if (event.isAutoRepeat && (enter || event.key === Qt.Key_Delete || event.key === Qt.Key_S))
            return true
        if (setting) {
            if (event.key === Qt.Key_Escape) {
                setting = false
                return true
            }
            return false
        }
        if (menuRow)
            return menu.key(event)
        if (event.key === Qt.Key_Escape)
            back()
        else if (event.key === Qt.Key_Comma && ctrl)
            openSettings()
        else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            if (ctrl) {
                const i = sources.indexOf(source)
                setSource(sources[(i + (event.key === Qt.Key_Backtab ? sources.length - 1 : 1)) % sources.length])
            } else {
                const i = views.indexOf(view)
                setView(views[(i + (event.key === Qt.Key_Backtab || shift ? views.length - 1 : 1)) % views.length])
            }
        } else if (ctrl && event.key === Qt.Key_Right)
            Music.control("skip")
        else if (ctrl && event.key === Qt.Key_Left)
            Music.control("prev")
        else if (ctrl && event.key === Qt.Key_R)
            Music.act(["play", "random", source])
        else if (ctrl && event.key === Qt.Key_S)
            star(selected)
        else if (ctrl && mode === "queue" && (event.key === Qt.Key_Up || event.key === Qt.Key_Down) && selected) {
            const to = selected.qi + (event.key === Qt.Key_Up ? -1 : 1)
            if (to >= 0 && to < Music.queue.length) {
                Music.act(["move", String(selected.qi), String(to)])
                list.currentIndex = to
            }
        } else if (event.key === Qt.Key_Delete && mode === "queue" && selected)
            Music.act(["remove", String(selected.qi)])
        else if (event.key === Qt.Key_Right && (mode === "home" || gridMode))
            moveSel(1, 0)
        else if (event.key === Qt.Key_Left && (mode === "home" || gridMode))
            moveSel(-1, 0)
        else if (event.key === Qt.Key_Down)
            moveSel(0, 1)
        else if (event.key === Qt.Key_Up)
            moveSel(0, -1)
        else if (event.key === Qt.Key_Space && shift)
            open(selected)
        else if (event.key === Qt.Key_Space && search.text === "")
            Music.control("toggle")
        else if (event.key === Qt.Key_Menu)
            selected && showMenu(selected, frame.width / 2 - 100, frame.height / 2 - 80)
        else if (enter && ctrl)
            play(selected, "next")
        else if (enter && shift)
            play(selected, "add")
        else if (enter)
            play(selected)
        else
            return false
        return true
    }

    readonly property bool gridMode: mode === "albums" || mode === "artists" || mode === "playlists"

    function openSettings() {
        setting = true
        Qt.callLater(settings.open)
    }

    screen: Store.screenFor("music")
    visible: Store.isOpen("music") || motion.leaving
    implicitWidth: Math.floor(Math.min(1100, (screen ? screen.width : 1280) - 80))
    implicitHeight: Math.floor(Math.min(720, (screen ? screen.height : 800) - 120))
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "torus-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Store.isOpen("music") ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onVisibleChanged: {
        Music.follow(visible)
        if (!visible) {
            setting = false
            menuRow = null
            return
        }
        const keep = Store.recalls("music")
        Music.loadServers()
        if (!keep) {
            detail = null
            stack = []
            view = "home"
            search.text = ""
        }
        if (view !== "queue" || !keep)
            load()
        Music.warm()
        search.forceActiveFocus()
    }

    Binding {
        target: Store
        property: "musicSpot"
        value: root.mode + "|" + (root.selected ? root.selected.title : "") + "|" + root.source + "|" + (root.failed ? "error" : root.loading ? "loading" : root.more ? "part" : "ready") + "|" + (root.mode === "home" ? root.home.sections.length : root.gridMode ? root.grid.length : root.listRows.length) + "|" + (root.setting ? "settings" : "")
    }

    Binding {
        target: Store
        property: "musicSel"
        value: list.currentIndex
    }

    function fly(back) {
        const spot = screen && Store.musicSpots[screen.name] ? Store.musicSpots[screen.name]() : null
        if (!spot || !np.track || !Island.player)
            return
        const home = Fly.boxIn(np.cover, frame, Theme.rSm)
        Fly.go("music", Island.player.trackArtUrl, back ? home : spot, back ? spot : home)
    }

    readonly property bool flown: Store.isOpen("music") && backingWindowVisible && width === implicitWidth
    onFlownChanged: if (flown) settled.restart(); else if (backingWindowVisible && !Store.isOpen("music") && !covered) fly(true)

    Timer {
        id: settled
        interval: 20
        onTriggered: if (root.flown) root.fly(false)
    }

    Timer {
        id: debounce
        interval: 120
        onTriggered: root.find(false)
    }

    Rectangle {
        id: frame
        PanelMotion {
            id: motion
            target: frame
            fresh: false
            name: "music"
            shown: Store.isOpen("music")
        }
        anchors.fill: parent
        radius: Theme.rPanel
        color: Qt.alpha(Theme.base, Theme.glassCard)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.35)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: Theme.sp5

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.sp6
                Text {
                    text: root.detail ? "󰁍" : "󰎆"
                    color: root.detail && backHover.hovered ? Theme.lavender : Theme.accent
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fsTitle
                    HoverHandler { id: backHover; margin: 4; cursorShape: root.detail ? Qt.PointingHandCursor : Qt.ArrowCursor }
                    enabled: !root.covered
                    Tap { reach: 4; quiet: !root.detail; onTapped: if (root.detail) root.back() }
                }
                TextInput {
                    id: search
                    Layout.fillWidth: true
                    color: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsXl
                    clip: true
                    onTextChanged: {
                        root.query = text.trim()
                        if (root.query !== "") {
                            root.detail = null
                            root.stack = []
                            root.loading = root.found.length === 0
                            root.more = true
                            if (root.source === "all" || root.source === "local")
                                root.find(true)
                            debounce.restart()
                        } else {
                            debounce.stop()
                            root.found = []
                            root.foundFor = ""
                            root.loading = false
                            root.more = false
                            root.failed = false
                        }
                    }
                    Keys.onPressed: event => {
                        if (root.handle(event))
                            event.accepted = true
                    }
                    Text {
                        visible: search.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.detail ? root.detail.head.title : "type to search songs, albums, artists"
                        elide: Text.ElideRight
                        width: search.width
                        color: Theme.overlay
                        font: search.font
                    }
                }
                Segmented {
                    visible: root.sources.length > 2
                    enabled: !root.covered
                    options: root.sources
                    labels: root.sources.map(s => s === "all" ? "All" : s === "local" ? "Local" : s)
                    current: root.source
                    activeFocusOnTab: false
                    onPicked: value => {
                        root.setSource(value)
                        search.forceActiveFocus()
                    }
                }
                PanelButton {
                    icon: "󰒓"
                    implicitHeight: 30
                    enabled: !root.covered
                    activeFocusOnTab: false
                    onClicked: root.openSettings()
                }
            }

            RowLayout {
                enabled: !root.covered
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.sp6

                ColumnLayout {
                    Layout.preferredWidth: 140
                    Layout.minimumWidth: 140
                    Layout.maximumWidth: 140
                    Layout.fillWidth: false
                    Layout.fillHeight: true
                    spacing: Theme.sp2
                    Repeater {
                        model: [["home", "󰋜", "Home"], ["albums", "󰀥", "Albums"], ["artists", "󰠃", "Artists"], ["playlists", "󰲸", "Playlists"], ["queue", "󰲹", "Queue"]]
                        Rectangle {
                            id: nav
                            required property var modelData
                            readonly property bool on: root.view === modelData[0] && !root.detail && root.query === ""
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: Theme.rSm
                            color: on ? Qt.alpha(Theme.accent, 0.18) : (navHover.hovered ? Qt.alpha(Theme.surface1, 0.6) : "transparent")
                            Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: nav.modelData[1]; color: nav.on ? Theme.accent : Theme.subtext; font.family: Theme.fontMono; font.pixelSize: Theme.fsLg }
                            Text { x: 36; anchors.verticalCenter: parent.verticalCenter; text: nav.modelData[2] + (nav.modelData[0] === "queue" && Music.queue.length ? "  " + Music.queue.length : ""); color: nav.on ? Theme.text : Theme.subtext; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd; font.weight: nav.on ? Font.DemiBold : Font.Normal }
                            HoverHandler { id: navHover; cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) Music.warm() }
                            Tap { onTapped: { root.setView(nav.modelData[0]); search.forceActiveFocus() } }
                        }
                    }
                    Item { Layout.fillHeight: true }
                    PanelButton {
                        Layout.fillWidth: true
                        icon: "󰒝"
                        label: "Shuffle"
                        activeFocusOnTab: false
                        onClicked: Music.act(["play", "random", root.source])
                    }
                }

                Item {
                    id: main
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Text {
                        id: noteLine
                        visible: root.notes.length > 0
                        width: parent.width
                        text: "󰀦  " + root.notes.join(", ")
                        elide: Text.ElideRight
                        color: Theme.peach
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsSm
                    }

                    ListView {
                        id: sections
                        visible: root.mode === "home"
                        anchors.fill: parent
                        anchors.topMargin: noteLine.visible ? 24 : 0
                        clip: true
                        spacing: Theme.sp7
                        model: root.home.sections
                        boundsBehavior: Flickable.StopAtBounds
                        delegate: Column {
                            id: sec
                            required property var modelData
                            required property int index
                            width: sections.width
                            spacing: Theme.sp4
                            Text {
                                text: sec.modelData.title
                                color: sec.index === root.homeSec ? Theme.text : Theme.subtext
                                font.family: Theme.fontUi
                                font.pixelSize: Theme.fsLg
                                font.weight: Font.DemiBold
                            }
                            ListView {
                                id: shelf
                                width: parent.width
                                height: 182
                                orientation: ListView.Horizontal
                                spacing: Theme.sp6
                                clip: true
                                model: sec.modelData.rows
                                currentIndex: sec.index === root.homeSec ? root.homeIdx : -1
                                onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
                                boundsBehavior: Flickable.StopAtBounds
                                delegate: MusicCard {
                                    required property var modelData
                                    required property int index
                                    row: modelData
                                    size: 140
                                    opacity: motion.arrive(sec.index * 3 + index)
                                    current: sec.index === root.homeSec && index === root.homeIdx
                                    onPicked: { root.homeSec = sec.index; root.homeIdx = index }
                                    onOpened: root.open(modelData)
                                    onPlayed: { root.homeSec = sec.index; root.homeIdx = index; root.play(modelData) }
                                }
                            }
                        }
                    }

                    GridView {
                        id: gridView
                        visible: root.gridMode
                        anchors.fill: parent
                        anchors.topMargin: noteLine.visible ? 24 : 0
                        clip: true
                        cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 170)))
                        cellHeight: cellWidth - 14 + 50
                        model: root.grid
                        keyNavigationWraps: false
                        boundsBehavior: Flickable.StopAtBounds
                        delegate: Item {
                            id: cell
                            required property var modelData
                            required property int index
                            width: gridView.cellWidth
                            height: gridView.cellHeight
                            opacity: motion.arrive(index)
                            MusicCard {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 4
                                row: cell.modelData
                                size: gridView.cellWidth - 18
                                current: cell.index === gridView.currentIndex
                                onPicked: gridView.currentIndex = cell.index
                                onOpened: root.open(cell.modelData)
                                onPlayed: { gridView.currentIndex = cell.index; root.play(cell.modelData) }
                            }
                        }
                    }

                    ListView {
                        id: list
                        visible: root.mode === "search" || root.mode === "detail" || root.mode === "queue"
                        anchors.fill: parent
                        anchors.topMargin: noteLine.visible ? 24 : 0
                        clip: true
                        spacing: 2
                        model: root.listRows
                        boundsBehavior: Flickable.StopAtBounds
                        highlightMoveDuration: 0
                        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                        header: DetailHead {
                            width: list.width
                            head: root.mode === "detail" ? root.detail.head : null
                            onPlay: shuffle => Music.act(["play", root.detail.head.kind, root.detail.head.source, root.detail.head.id].concat(shuffle ? [] : ["0"]))
                            onQueue: Music.act(["add", root.detail.head.kind, root.detail.head.source, root.detail.head.id])
                        }
                        section.property: "group"
                        section.delegate: Text {
                            required property string section
                            height: 28
                            verticalAlignment: Text.AlignBottom
                            text: section
                            color: Theme.subtext
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fsSm
                            font.weight: Font.DemiBold
                        }
                        delegate: MusicRow {
                            required property var modelData
                            required property int index
                            width: list.width
                            opacity: motion.arrive(index)
                            row: modelData
                            starred: root.starredOf(modelData)
                            current: index === list.currentIndex
                            playing: root.mode === "queue" ? modelData.qi === Music.pos : (!!Music.current && Music.current.id === modelData.id && Music.current.source === modelData.source)
                            onPicked: list.currentIndex = index
                            onPlayed: { list.currentIndex = index; root.play(modelData) }
                            onQueued: root.play(modelData, "add")
                            onMenu: (x, y) => {
                                const p = mapToItem(frame, x, y)
                                root.showMenu(modelData, p.x, p.y)
                            }
                        }
                    }

                    CardState {
                        anchors.fill: parent
                        status: root.failed ? "error"
                            : (root.loading || root.more) && (root.mode === "home" ? root.home.sections.length : root.gridMode ? root.grid.length : root.listRows.length) === 0 ? "loading"
                            : (root.mode === "home" ? root.home.sections.length : root.gridMode ? root.grid.length : root.listRows.length) > 0 ? "ready"
                            : "empty"
                        retryable: true
                        text: status === "error" ? root.failure
                            : status === "loading" ? ""
                            : root.mode === "queue" ? "The queue is empty. Enter on anything plays it, Shift+Enter adds it here."
                            : root.mode === "search" ? "Nothing matches " + root.query
                            : root.mode === "detail" ? "Nothing in here"
                            : Music.servers.length === 0 && Music.localCount === 0 ? (Music.indexing ? "Reading your music folder ..." : "No music yet. Put files in " + Music.folder + ", or add a Subsonic server with the cog (Ctrl ,).")
                            : "Nothing here yet"
                        onRetry: root.mode === "search" ? root.find(false) : root.detail ? root.open(root.detail.row) : root.load()
                    }
                }
            }

            NowPlaying {
                id: np
                enabled: !root.covered
                Layout.fillWidth: true
                onOpenQueue: root.setView("queue")
            }

            KeyHints {
                Layout.fillWidth: true
                hints: root.mode === "queue" ? [["↵", "play"], ["Del", "remove"], ["Ctrl ↑ / ↓", "move"], ["Space", "pause"], ["Ctrl ← / →", "prev / next"], ["Tab", "views"], ["Esc", "close"]]
                    : [["↵", "play"], ["Shift ↵", "queue"], ["Ctrl ↵", "next"], ["Shift Space", "open"], ["Ctrl S", "star"], ["Ctrl R", "shuffle"], ["Tab", "views"], ["Ctrl ,", "settings"], ["Esc", root.detail || root.query ? "back" : "close"]]
            }
        }

        MouseArea {
            anchors.fill: parent
            z: 19
            visible: !!root.menuRow
            onClicked: { root.menuRow = null; search.forceActiveFocus() }
        }
        MusicMenu {
            id: menu
            z: 20
            visible: !!root.menuRow
            items: root.menuItems(root.menuRow)
            onChosen: what => root.choose(what)
            onDismissed: { root.menuRow = null; search.forceActiveFocus() }
        }

        MusicSettings {
            id: settings
            anchors.fill: parent
            z: 30
            visible: root.setting
            onClosed: {
                root.setting = false
                search.forceActiveFocus()
            }
            onChanged: root.load()
        }
    }
}
