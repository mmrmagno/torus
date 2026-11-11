import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services

Card {
    id: card

    title: "commute"
    implicitHeight: body.implicitHeight + 44
    property bool editing: false
    property int expanded: -1
    readonly property var trips: Commute.configured ? Commute.connections : []
    readonly property var first: trips.length > 0 ? trips[0] : null
    onTripsChanged: expanded = -1

    function hhmm(t) {
        return t ? Qt.formatDateTime(new Date(t * 1000), "HH:mm") : "--:--"
    }
    function leaveIn(t) {
        const m = Math.ceil((t * 1000 - clock.date.getTime()) / 60000)
        return m <= 0 ? "leave now" : m < 60 ? "leave in " + m + " min" : "leave at " + hhmm(t)
    }
    function changes(n) {
        return n === 0 ? "direct" : n + (n === 1 ? " change" : " changes")
    }
    function lineColor(line) {
        const cat = (line || "").split(" ")[0]
        if (["IC", "ICE", "IR", "EC", "EN", "TGV", "RJ", "RJX", "NJ", "PE", "GEX"].indexOf(cat) >= 0)
            return Theme.red
        if (["S", "SN", "R", "RE", "RB"].indexOf(cat) >= 0)
            return Theme.blue
        if (["T", "B", "BUS", "NFB", "NFO", "M"].indexOf(cat) >= 0)
            return Theme.green
        return Theme.mauve
    }
    function edit() {
        homeField.text = Commute.config.home
        workField.text = Commute.config.work
        editing = true
        homeField.focusInput()
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.sp5

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp4
            Text {
                text: "󰔬"
                color: Theme.accent
                font.family: Theme.fontMono
                font.pixelSize: Theme.fsTitle
            }
            Text {
                Layout.fillWidth: true
                text: Commute.result.fromLabel ? Commute.result.fromLabel + "  →  " + Commute.result.toLabel : "Home and work"
                color: Theme.text
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsLg
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            IconButton { glyph: Commute.alertMuted ? "󰂛" : "󰂚"; visible: Commute.configured && Commute.alertsOn && !card.editing; active: Commute.alertMuted; onClicked: Commute.muteToday(!Commute.alertMuted) }
            IconButton { glyph: "󰓡"; visible: Commute.configured && !card.editing; onClicked: Commute.swap() }
            IconButton { glyph: "󰑓"; visible: Commute.configured && !card.editing; spinning: Commute.busy; onClicked: Commute.refresh() }
            IconButton { glyph: "󰒓"; active: card.editing; onClicked: card.editing ? card.editing = false : card.edit() }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: card.editing
            spacing: Theme.sp3
            Field { id: homeField; Layout.fillWidth: true; label: "Home"; placeholder: "street, postcode and town"; onAccepted: workField.focusInput() }
            Field { id: workField; Layout.fillWidth: true; label: "Work"; placeholder: "street, postcode and town"; onAccepted: saveButton.clicked() }
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "Saved in ~/.config/torus/commute.json"
                    color: Theme.overlay
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsXs
                    elide: Text.ElideRight
                }
                PanelButton { label: "Cancel"; implicitHeight: 28; onClicked: card.editing = false }
                PanelButton {
                    id: saveButton
                    label: "Save"
                    active: true
                    implicitHeight: 28
                    onClicked: {
                        Commute.save(homeField.text, workField.text)
                        card.editing = false
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: !card.editing && !Commute.configured
            spacing: Theme.sp4
            Text {
                Layout.fillWidth: true
                text: "Add your home and work address to see the next trains."
                color: Theme.subtext
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsMd
                wrapMode: Text.Wrap
            }
            PanelButton { label: "Set up"; icon: "󰒓"; onClicked: card.edit() }
        }

        Rectangle {
            Layout.fillWidth: true
            visible: !card.editing && card.first !== null
            implicitHeight: hero.implicitHeight + 24
            radius: Theme.rSm
            color: heroHover.hovered ? Qt.alpha(Theme.accent, 0.14) : Qt.alpha(Theme.accent, 0.08)
            border.width: 1
            border.color: Qt.alpha(Theme.accent, 0.35)
            Behavior on color { ColorAnimation { duration: Theme.durFast } }
            HoverHandler { id: heroHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: card.expanded = card.expanded === 0 ? -1 : 0 }

            ColumnLayout {
                id: hero
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: Theme.sp4
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.sp5
                    ColumnLayout {
                        spacing: Theme.sp1
                        Text {
                            text: card.first ? card.leaveIn(card.first.dep) : ""
                            color: Theme.accent
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fsTitle
                            font.weight: Font.Bold
                        }
                        Text {
                            text: card.first ? card.hhmm(card.first.dep) + "  →  " + card.hhmm(card.first.arr) : ""
                            color: Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fsMd
                        }
                    }
                    Item { Layout.fillWidth: true }
                    ColumnLayout {
                        spacing: Theme.sp2
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Lines { Layout.alignment: Qt.AlignRight; lines: card.first ? card.first.lines : [] }
                        Text {
                            Layout.alignment: Qt.AlignRight
                            text: card.first ? card.first.minutes + " min · " + card.changes(card.first.changes) + (card.first.platform ? " · pl. " + card.first.platform : "") : ""
                            color: Theme.subtext
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fsSm
                        }
                        Text {
                            Layout.alignment: Qt.AlignRight
                            visible: card.first !== null && card.first.delay > 0
                            text: card.first ? "+" + card.first.delay + " min late" : ""
                            color: Theme.peach
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fsSm
                        }
                    }
                }
                Legs { Layout.fillWidth: true; visible: card.expanded === 0; trip: card.first }
            }
        }

        Repeater {
            model: card.editing ? [] : card.trips.slice(1)
            Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property int slot: index + 1
                Layout.fillWidth: true
                implicitHeight: rowBody.implicitHeight + 16
                radius: Theme.rSm
                color: rowHover.hovered ? Theme.surface1 : Qt.alpha(Theme.base, 0.35)
                Behavior on color { ColorAnimation { duration: Theme.durFast } }
                HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: card.expanded = card.expanded === row.slot ? -1 : row.slot }

                ColumnLayout {
                    id: rowBody
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 8
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: Theme.sp3
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.sp5
                        Text {
                            text: card.hhmm(row.modelData.dep) + " → " + card.hhmm(row.modelData.arr)
                            color: Theme.text
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fsMd
                        }
                        Lines { lines: row.modelData.lines }
                        Item { Layout.fillWidth: true }
                        Text {
                            visible: row.modelData.fastest === true
                            text: "fastest"
                            color: Theme.green
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fsXs
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: row.modelData.minutes + " min · " + card.changes(row.modelData.changes) + (row.modelData.delay > 0 ? " · +" + row.modelData.delay : "")
                            color: row.modelData.delay > 0 ? Theme.peach : Theme.subtext
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fsSm
                        }
                    }
                    Legs { Layout.fillWidth: true; visible: card.expanded === row.slot; trip: row.modelData }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: !card.editing && Commute.configured && (Commute.result.message || "") !== ""
            text: Commute.result.message || ""
            color: Commute.result.stale ? Theme.overlay : Theme.peach
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsSm
            wrapMode: Text.Wrap
        }

        RowLayout {
            Layout.fillWidth: true
            visible: !card.editing && Commute.configured
            Text {
                Layout.fillWidth: true
                text: "Timetable data: opentransportdata.swiss" + (Commute.result.updated ? " · " + card.hhmm(Commute.result.updated) : "")
                color: Theme.overlay
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsXs
                elide: Text.ElideRight
            }
            Text {
                visible: !!Commute.result.sbb
                text: "SBB ↗"
                color: sbbHover.hovered ? Theme.accent : Theme.subtext
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsSm
                HoverHandler { id: sbbHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: Qt.openUrlExternally(Commute.result.sbb) }
            }
        }
    }

    component Lines: Row {
        property var lines: []
        spacing: Theme.sp2
        Repeater {
            model: parent.lines
            Rectangle {
                required property var modelData
                width: chip.implicitWidth + 10
                height: 18
                radius: Theme.rXs
                color: Qt.alpha(card.lineColor(modelData), 0.18)
                Text {
                    id: chip
                    anchors.centerIn: parent
                    text: parent.modelData
                    color: card.lineColor(parent.modelData)
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fsXs
                    font.weight: Font.Bold
                }
            }
        }
    }

    component Legs: Column {
        property var trip: null
        spacing: 0
        Repeater {
            model: parent.trip ? parent.trip.legs : []
            Item {
                id: legRow
                required property var modelData
                required property int index
                readonly property bool ride: modelData.kind === "ride"
                width: parent ? parent.width : 0
                height: ride ? 34 : 22
                Rectangle {
                    x: 4
                    width: 2
                    height: parent.height
                    color: legRow.ride ? Qt.alpha(card.lineColor(legRow.modelData.line), 0.6) : Qt.alpha(Theme.overlay, 0.4)
                }
                Rectangle {
                    visible: legRow.ride
                    x: 0
                    y: 4
                    width: 10
                    height: 10
                    radius: 5
                    color: card.lineColor(legRow.modelData.line)
                }
                Column {
                    x: 20
                    width: parent.width - 20
                    spacing: 0
                    Text {
                        width: parent.width
                        text: legRow.ride
                            ? card.hhmm(legRow.modelData.dep) + "  " + legRow.modelData.line + "  " + legRow.modelData.from + "  →  " + legRow.modelData.to
                            : "walk " + Math.max(1, legRow.modelData.minutes) + " min" + (legRow.modelData.to ? " to " + legRow.modelData.to : "")
                        color: legRow.ride ? Theme.text : Theme.overlay
                        font.family: Theme.fontUi
                        font.pixelSize: legRow.ride ? Theme.fsSm : Theme.fsXs
                        elide: Text.ElideRight
                    }
                    Text {
                        visible: legRow.ride
                        width: parent.width
                        text: (legRow.modelData.platform ? "platform " + legRow.modelData.platform + "  ·  " : "") + "arrives " + card.hhmm(legRow.modelData.arr) + (legRow.modelData.delay > 0 ? "  ·  +" + legRow.modelData.delay + " min" : "")
                        color: legRow.modelData.delay > 0 ? Theme.peach : Theme.overlay
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsXs
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    component IconButton: Rectangle {
        id: ib
        property string glyph: ""
        property bool active: false
        property bool spinning: false
        signal clicked
        implicitWidth: 28
        implicitHeight: 28
        radius: 14
        color: active ? Theme.accent : (ibHover.hovered ? Theme.surface1 : "transparent")
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        Text {
            id: ibGlyph
            anchors.centerIn: parent
            text: ib.glyph
            color: ib.active ? Theme.crust : Theme.subtext
            font.family: Theme.fontMono
            font.pixelSize: Theme.icon
            RotationAnimation on rotation { running: ib.spinning && Theme.motion > 0; from: 0; to: 360; duration: 900; loops: Animation.Infinite; onStopped: ibGlyph.rotation = 0 }
        }
        HoverHandler { id: ibHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: ib.clicked() }
    }

    component Field: ColumnLayout {
        id: field
        property alias text: input.text
        property string label: ""
        property string placeholder: ""
        signal accepted
        function focusInput() { input.forceActiveFocus() }
        spacing: Theme.sp2
        Text {
            text: field.label
            color: Theme.subtext
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsSm
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 32
            radius: Theme.rSm
            color: Qt.alpha(Theme.base, 0.6)
            border.width: 1
            border.color: input.activeFocus ? Theme.accent : Theme.surface1
            Behavior on border.color { ColorAnimation { duration: Theme.durFast } }
            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                selectByMouse: true
                color: Theme.text
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsMd
                onAccepted: field.accepted()
                Keys.onEscapePressed: card.editing = false
            }
            Text {
                anchors.fill: input
                verticalAlignment: Text.AlignVCenter
                visible: input.text === ""
                text: field.placeholder
                color: Theme.overlay
                font: input.font
                elide: Text.ElideRight
            }
        }
    }
}
