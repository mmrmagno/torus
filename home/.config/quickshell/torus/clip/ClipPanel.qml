import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components
import qs.services

PanelWindow {
    id: root

    screen: Store.screenFor("clip")
    visible: Store.isOpen("clip") || motion.leaving
    implicitWidth: 900
    implicitHeight: 560
    exclusiveZone: 0
    color: "transparent"
    mask: Region { item: clipFrame }
    WlrLayershell.namespace: "torus-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Store.isOpen("clip") ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property var kinds: [["all", "All", "󰅌"], ["text", "Text", "󰦨"], ["link", "Links", "󰌹"], ["image", "Images", "󰋩"], ["color", "Colors", "󰏘"], ["code", "Code", "󰅩"]]
    readonly property var current: list.currentIndex >= 0 && list.currentIndex < Clip.shown.length ? Clip.shown[list.currentIndex] : null
    property real openStart: 0
    property string fullText: ""
    property string fullKey: ""
    property bool moved: false

    Connections {
        target: Clip
        function onShownChanged() {
            if (!root.moved && list.count > 0) {
                list.currentIndex = 0
                list.positionViewAtBeginning()
            }
        }
    }

    function cycleKind(d) {
        const i = kinds.findIndex(k => k[0] === Clip.kindFilter)
        Clip.kindFilter = kinds[(i + d + kinds.length) % kinds.length][0]
        list.currentIndex = 0
    }

    function esc(s) {
        return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    }

    function marked(text, marks) {
        const t = text.length > 240 ? text.slice(0, 240) : text
        if (!marks)
            return esc(t)
        const at = {}
        for (const m of marks.split(","))
            at[m] = true
        let out = ""
        for (let i = 0; i < t.length; i++)
            out += at[i] ? "<font color=\"" + Theme.accent + "\"><b>" + esc(t[i]) + "</b></font>" : esc(t[i])
        return out
    }

    function deleteCurrent() {
        if (Clip.manage && Clip.markedCount > 0) {
            Clip.deleteMarked()
            return
        }
        const keep = list.currentIndex
        if (Clip.remove(root.current) === "deleted")
            Qt.callLater(() => { list.currentIndex = Math.min(keep, list.count - 1) })
    }

    function hsl(c) {
        const r = c.r, g = c.g, b = c.b
        const mx = Math.max(r, g, b), mn = Math.min(r, g, b)
        const l = (mx + mn) / 2
        let h = 0, s = 0
        if (mx !== mn) {
            const d = mx - mn
            s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn)
            h = mx === r ? (g - b) / d + (g < b ? 6 : 0) : mx === g ? (b - r) / d + 2 : (r - g) / d + 4
            h *= 60
        }
        return "hsl(" + Math.round(h) + ", " + Math.round(s * 100) + "%, " + Math.round(l * 100) + "%)"
    }

    onCurrentChanged: {
        if (!root.current || root.current.key !== Clip.armed)
            if (Clip.armed !== "" && !Clip.armed.startsWith("clear:") && Clip.armed !== "marked")
                Clip.armed = ""
        previewTimer.restart()
    }

    onVisibleChanged: if (visible) {
        openStart = Date.now()
        moved = false
        Clip.kindFilter = "all"
        search.text = ""
        Clip.filter = ""
        list.currentIndex = 0
        search.forceActiveFocus()
    }

    Connections {
        target: list.Window.window
        enabled: Clip.openMs < 0 && Store.isOpen("clip")
        function onFrameSwapped() {
            if (list.count > 0 && Clip.openedAt > 0)
                Clip.openMs = Date.now() - Clip.openedAt
        }
    }

    Timer {
        id: previewTimer
        interval: 90
        onTriggered: {
            const e = root.current
            if (!e || e.kind === "image" || e.key === root.fullKey)
                return
            root.fullKey = e.key
            root.fullText = e.text
            full.command = e.pinned ? ["head", "-c", "20000", "--", Clip.pinDir + "/" + e.file] : ["sh", "-c", "printf '%s\\n' \"$1\" | cliphist decode | head -c 20000", "sh", e.line]
            full.running = true
        }
    }

    Process {
        id: full
        stdout: StdioCollector { onStreamFinished: if (text !== "") root.fullText = text }
    }

    Rectangle {
        id: clipFrame
        PanelMotion {
            id: motion
            target: clipFrame
            shown: Store.isOpen("clip")
        }
        anchors.fill: parent
        transformOrigin: Item.Top
        radius: 16
        color: Qt.alpha(Theme.base, Theme.glass)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.35)

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: Theme.sp7

            ColumnLayout {
                Layout.preferredWidth: 520
                Layout.maximumWidth: 520
                Layout.fillWidth: false
                Layout.fillHeight: true
                spacing: Theme.sp5

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: Theme.rCard
                    color: Theme.surface0
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: Theme.sp5
                        Text {
                            text: Clip.manage ? "󰒆" : "󰅌"
                            color: Theme.accent
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fsXl
                        }
                        TextInput {
                            id: search
                            Layout.fillWidth: true
                            color: Theme.text
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fsLg
                            onTextChanged: {
                                root.moved = false
                                Clip.filter = text
                                list.currentIndex = 0
                            }
                            Keys.onPressed: event => {
                                if ([Qt.Key_Down, Qt.Key_Up, Qt.Key_PageDown, Qt.Key_PageUp, Qt.Key_Delete, Qt.Key_Space].indexOf(event.key) >= 0)
                                    root.moved = true
                                const ctrl = event.modifiers & Qt.ControlModifier
                                const e = root.current
                                if (event.key === Qt.Key_Escape)
                                    Store.setOpen("clip", false)
                                else if (event.key === Qt.Key_Down && ctrl && e && e.pinned)
                                    { Clip.movePin(list.currentIndex, list.currentIndex + 1); list.currentIndex = Math.min(list.currentIndex + 1, Clip.pins.length - 1) }
                                else if (event.key === Qt.Key_Up && ctrl && e && e.pinned)
                                    { Clip.movePin(list.currentIndex, list.currentIndex - 1); list.currentIndex = Math.max(0, list.currentIndex - 1) }
                                else if (event.key === Qt.Key_Down) {
                                    if (list.currentIndex >= list.count - 1 && Clip.matches > list.count)
                                        Clip.limit += 50
                                    list.incrementCurrentIndex()
                                } else if (event.key === Qt.Key_Up)
                                    list.decrementCurrentIndex()
                                else if (event.key === Qt.Key_PageDown)
                                    list.currentIndex = Math.min(list.count - 1, list.currentIndex + 8)
                                else if (event.key === Qt.Key_PageUp)
                                    list.currentIndex = Math.max(0, list.currentIndex - 8)
                                else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && e)
                                    Clip.copy(e)
                                else if (event.key === Qt.Key_Delete && (e || Clip.markedCount > 0))
                                    root.deleteCurrent()
                                else if (event.key === Qt.Key_Space && Clip.manage && e)
                                    { Clip.toggleMark(e); list.incrementCurrentIndex() }
                                else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier)))
                                    root.cycleKind(-1)
                                else if (event.key === Qt.Key_Tab)
                                    root.cycleKind(1)
                                else if (event.key === Qt.Key_P && ctrl && e)
                                    Clip.togglePin(e)
                                else if (event.key === Qt.Key_M && ctrl)
                                    Clip.manage = !Clip.manage
                                else
                                    return
                                event.accepted = true
                            }
                            Text {
                                visible: search.text === ""
                                anchors.verticalCenter: parent.verticalCenter
                                text: Clip.manage ? "Select entries: Space selects, Del deletes" : "Search the clipboard"
                                color: Theme.overlay
                                font: search.font
                            }
                        }
                    }
                }

                Row {
                    Layout.fillWidth: true
                    spacing: Theme.sp3
                    Repeater {
                        model: root.kinds
                        Rectangle {
                            id: chip
                            required property var modelData
                            readonly property bool on: Clip.kindFilter === modelData[0]
                            width: chipRow.implicitWidth + 18
                            height: 26
                            radius: 13
                            color: on ? Theme.accent : (chipHover.hovered ? Theme.surface1 : Theme.surface0)
                            Behavior on color { ColorAnimation { duration: Theme.durFast } }
                            Row {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 5
                                Text { text: chip.modelData[2]; color: chip.on ? Theme.crust : Theme.accent; font.family: Theme.fontMono; font.pixelSize: Theme.fsMd; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: chip.modelData[1]; color: chip.on ? Theme.crust : Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; anchors.verticalCenter: parent.verticalCenter }
                            }
                            HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: { Clip.kindFilter = chip.modelData[0]; list.currentIndex = 0 } }
                        }
                    }
                }

                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: Theme.sp2
                    model: Clip.rows
                    cacheBuffer: 200
                    highlightMoveDuration: 120
                    boundsBehavior: Flickable.StopAtBounds
                    section.property: "group"
                    section.delegate: Text {
                        required property string section
                        visible: section !== "Matches"
                        height: visible ? 26 : 0
                        verticalAlignment: Text.AlignBottom
                        leftPadding: 4
                        bottomPadding: 4
                        text: section.toUpperCase()
                        color: Theme.overlay
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsXs
                        font.letterSpacing: 1.2
                    }

                    delegate: Rectangle {
                        id: row
                        required property int index
                        required property string key
                        required property string text
                        required property string kind
                        required property string image
                        required property bool pinned
                        required property string swatch
                        required property string host
                        required property string rest
                        required property string marks
                        required property string line
                        readonly property bool isCurrent: ListView.isCurrentItem
                        readonly property bool armed: Clip.armed === key || (Clip.armed === "marked" && pinned && Clip.marked[key] === true)
                        readonly property bool isMarked: Clip.marked[key] === true
                        readonly property string thumb: pinned ? image : (kind === "image" ? (Clip.thumbReady, Clip.thumbFor(line)) : "")
                        width: list.width
                        height: kind === "image" ? 72 : (kind === "code" ? 54 : 42)
                        radius: Theme.radius
                        opacity: grip.dragging ? 0.6 : 1
                        color: armed ? Qt.alpha(Theme.red, 0.22) : (isCurrent ? Qt.alpha(Theme.accent, 0.18) : (isMarked ? Qt.alpha(Theme.accent, 0.08) : (hover.hovered ? Theme.surface0 : "transparent")))
                        border.width: armed || isCurrent ? 1 : 0
                        border.color: armed ? Theme.red : Qt.alpha(Theme.accent, 0.5)
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }
                        Component.onCompleted: if (kind === "image" && !pinned) Clip.wantThumb(line)
                        onThumbChanged: if (thumb === "" && kind === "image" && !pinned) Clip.wantThumb(line)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            anchors.leftMargin: 10
                            spacing: Theme.sp5
                            Rectangle {
                                visible: Clip.manage
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                radius: 5
                                color: row.isMarked ? Theme.accent : "transparent"
                                border.width: 1
                                border.color: row.isMarked ? Theme.accent : Theme.overlay
                                Text { anchors.centerIn: parent; visible: row.isMarked; text: "󰄬"; color: Theme.crust; font.family: Theme.fontMono; font.pixelSize: Theme.fsXs }
                            }
                            Rectangle {
                                visible: row.kind === "color"
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                radius: 8
                                color: row.swatch || "transparent"
                                border.width: 1
                                border.color: Qt.alpha(Theme.text, 0.2)
                            }
                            Text {
                                visible: row.kind !== "color" && row.kind !== "image"
                                Layout.preferredWidth: 24
                                horizontalAlignment: Text.AlignHCenter
                                text: ({ link: "󰌹", email: "󰇮", path: "󰉋", code: "󰅩", text: "󰦨" })[row.kind] || "󰦨"
                                color: row.kind === "link" ? Theme.blue : (row.kind === "code" ? Theme.green : (row.kind === "path" ? Theme.yellow : Theme.overlay))
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fsXl
                            }
                            ClippingRectangle {
                                visible: row.kind === "image"
                                Layout.preferredWidth: 96
                                Layout.preferredHeight: 58
                                radius: Theme.rSm
                                color: Qt.alpha(Theme.crust, 0.6)
                                Image {
                                    anchors.fill: parent
                                    source: row.thumb
                                    sourceSize.width: 192
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: false
                                    onStatusChanged: if (status === Image.Error && !row.pinned) Clip.thumbLost(row.line)
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: row.armed ? "<font color=\"" + Theme.red + "\"><b>" + (Clip.armed === "marked" ? "delete selected pins? Del again" : "delete pin? Del again") + "</b></font>  " + root.esc(row.text.slice(0, 80))
                                    : (row.kind === "link" && row.marks === "" ? "<b>" + root.esc(row.host) + "</b><font color=\"" + Theme.overlay + "\">" + root.esc(row.rest) + "</font>" : root.marked(row.text, row.marks))
                                textFormat: Text.StyledText
                                color: row.kind === "image" ? Theme.subtext : Theme.text
                                font.family: row.kind === "code" || row.kind === "path" || row.kind === "color" ? Theme.fontMono : Theme.fontUi
                                font.pixelSize: row.kind === "code" ? Theme.fsSm : Theme.fsMd
                                elide: Text.ElideRight
                                maximumLineCount: row.kind === "code" ? 2 : 1
                                wrapMode: row.kind === "code" ? Text.WrapAnywhere : Text.NoWrap
                            }
                            Text {
                                visible: row.pinned || hover.hovered || pinHover.containsMouse || delHover.containsMouse || row.isCurrent
                                text: "󰐃"
                                color: row.pinned ? Theme.peach : (pinHover.containsMouse ? Theme.accent : Theme.overlay)
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fsLg
                                MouseArea {
                                    id: pinHover
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Clip.togglePin(Clip.entryAt(row.index))
                                }
                            }
                            Text {
                                text: "󰆴"
                                color: delHover.containsMouse || row.armed ? Theme.red : Theme.overlay
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fsLg
                                MouseArea {
                                    id: delHover
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        list.currentIndex = row.index
                                        root.deleteCurrent()
                                    }
                                }
                            }
                            Text {
                                visible: row.pinned
                                text: "󰇛"
                                color: grip.containsMouse ? Theme.accent : Theme.overlay
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fsLg
                                MouseArea {
                                    id: grip
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    hoverEnabled: true
                                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                    property bool dragging: false
                                    onPressed: dragging = true
                                    onReleased: mouse => {
                                        dragging = false
                                        const p = grip.mapToItem(list.contentItem, mouse.x, mouse.y)
                                        const to = list.indexAt(20, p.y)
                                        if (to >= 0 && to < Clip.pins.length && to !== row.index) {
                                            Clip.movePin(row.index, to)
                                            list.currentIndex = to
                                        }
                                    }
                                }
                            }
                        }
                        MouseArea {
                            id: hover
                            readonly property bool hovered: containsMouse
                            anchors.fill: parent
                            z: -1
                            hoverEnabled: true
                            onClicked: {
                                if (Clip.manage)
                                    Clip.toggleMark(Clip.entryAt(row.index))
                                else
                                    Clip.copy(Clip.entryAt(row.index))
                            }
                        }
                    }

                    footer: Item {
                        width: list.width
                        height: Clip.matches > list.count ? 40 : 0
                        visible: height > 0
                        PanelButton {
                            anchors.centerIn: parent
                            implicitHeight: 28
                            icon: "󰁅"
                            label: "Show " + Math.min(50, Clip.matches - list.count) + " more of " + (Clip.matches - list.count)
                            onClicked: Clip.limit += 50
                        }
                    }

                    CardState {
                        anchors.fill: parent
                        status: list.count > 0 ? "ready" : "empty"
                        text: Clip.entries.length === 0 && Clip.pins.length === 0 ? "Copy something and it shows up here" : "Nothing matches"
                    }
                }

                RowLayout {
                    id: footer
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    spacing: Theme.sp5
                    Repeater {
                        model: Clip.manage ? [["Space", "select"], ["Del", Clip.markedCount > 0 ? "delete " + Clip.markedCount : "delete"], ["Ctrl M", "done"]] : [["↵", "copy"], ["Ctrl P", "pin"], ["Del", "remove"], ["Tab", "type"]]
                        Row {
                            id: hint
                            required property var modelData
                            spacing: Theme.sp2
                            Keycap { text: hint.modelData[0]; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: hint.modelData[1]; color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    PanelButton {
                        visible: Clip.manage
                        implicitHeight: 26
                        icon: "󰆴"
                        label: Clip.armed === "clear:" + Clip.kindFilter ? "Sure? click again" : (Clip.kindFilter === "all" ? "Clear all but pins" : "Clear " + root.kinds.find(k => k[0] === Clip.kindFilter)[1].toLowerCase())
                        active: Clip.armed === "clear:" + Clip.kindFilter
                        onClicked: Clip.clearKind(Clip.kindFilter)
                    }
                    PanelButton {
                        visible: !Clip.manage
                        implicitHeight: 26
                        icon: "󰒆"
                        label: "Select"
                        onClicked: Clip.manage = true
                    }
                    Text {
                        visible: !Clip.manage
                        text: Clip.matches + (Clip.matches === 1 ? " entry" : " entries")
                        color: Theme.overlay
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsSm
                    }
                }
            }

            Rectangle {
                id: preview
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.rCard
                color: Qt.alpha(Theme.surface0, 0.55)
                border.width: 1
                border.color: Qt.alpha(Theme.surface1, 0.6)
                readonly property var e: root.current

                CardState {
                    anchors.fill: parent
                    anchors.margins: 14
                    status: preview.e ? "ready" : "empty"
                    text: "Nothing selected"
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: Theme.sp5
                    visible: preview.e !== null

                    Text {
                        text: preview.e ? (preview.e.pinned ? "PINNED · " : "") + (preview.e.kind || "text").toUpperCase() + (preview.e.kind === "text" || preview.e.kind === "code" ? "  ·  " + root.fullText.length + " chars" : "") : ""
                        color: Theme.overlay
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsXs
                        font.letterSpacing: 1.2
                    }

                    Image {
                        visible: preview.e !== null && preview.e.kind === "image"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        source: preview.e && preview.e.kind === "image" ? (preview.e.pinned ? preview.e.image : (Clip.thumbReady, Clip.thumbFor(preview.e.line))) : ""
                        sourceSize.width: 640
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: false
                    }

                    ColumnLayout {
                        visible: preview.e !== null && preview.e.kind === "color"
                        Layout.fillWidth: true
                        spacing: Theme.sp5
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 140
                            radius: Theme.rCard
                            color: preview.e && preview.e.color ? preview.e.color : "transparent"
                            border.width: 1
                            border.color: Qt.alpha(Theme.text, 0.2)
                        }
                        Repeater {
                            model: preview.e && preview.e.kind === "color" ? (function () {
                                const c = Qt.color(preview.e.color)
                                return ["hex  " + c.toString(), "rgb  rgb(" + Math.round(c.r * 255) + ", " + Math.round(c.g * 255) + ", " + Math.round(c.b * 255) + ")", "hsl  " + root.hsl(c)]
                            })() : []
                            Text { required property string modelData; text: modelData; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fsMd }
                        }
                    }

                    ColumnLayout {
                        visible: preview.e !== null && preview.e.kind === "link"
                        Layout.fillWidth: true
                        spacing: Theme.sp3
                        Text { text: preview.e ? preview.e.host || "" : ""; color: Theme.blue; font.family: Theme.fontUi; font.pixelSize: Theme.fsXl; font.weight: Font.DemiBold }
                        Text { Layout.fillWidth: true; text: root.fullText; wrapMode: Text.WrapAnywhere; color: Theme.subtext; font.family: Theme.fontMono; font.pixelSize: Theme.fsSm; textFormat: Text.PlainText }
                    }

                    Flickable {
                        visible: preview.e !== null && preview.e.kind !== "image" && preview.e.kind !== "color" && preview.e.kind !== "link"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentHeight: fullBody.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        Text {
                            id: fullBody
                            width: parent.width
                            text: root.fullText
                            wrapMode: Text.Wrap
                            textFormat: Text.PlainText
                            color: Theme.text
                            font.family: preview.e && (preview.e.kind === "code" || preview.e.kind === "path") ? Theme.fontMono : Theme.fontUi
                            font.pixelSize: Theme.fsMd
                        }
                    }

                    Item { Layout.fillHeight: true; visible: preview.e !== null && (preview.e.kind === "color" || preview.e.kind === "link") }
                }
            }
        }
    }
}
