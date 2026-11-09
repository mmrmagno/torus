import QtQuick
import Quickshell
import qs
import qs.services

Column {
    id: root
    property date shown: new Date()
    property date picked: new Date()
    readonly property var dayEvents: Agenda.onDay(picked)
    readonly property var today: clock.date
    spacing: Theme.sp3

    SystemClock { id: clock; precision: SystemClock.Minutes }

    function cells() {
        const y = shown.getFullYear(), m = shown.getMonth()
        const first = (new Date(y, m, 1).getDay() + 6) % 7
        const days = new Date(y, m + 1, 0).getDate()
        const out = []
        for (let i = 0; i < first; i++) out.push(0)
        for (let d = 1; d <= days; d++) out.push(d)
        while (out.length % 7) out.push(0)
        return out
    }

    Row {
        width: parent.width
        Text {
            width: parent.width - 112
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDate(root.shown, "MMMM yyyy")
            color: Theme.text
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsLg
            font.weight: Font.DemiBold
        }
        Rectangle {
            id: todayBtn
            readonly property bool away: Qt.formatDate(root.picked, "yyyyMMdd") !== Qt.formatDate(root.today, "yyyyMMdd") || root.shown.getMonth() !== root.today.getMonth() || root.shown.getFullYear() !== root.today.getFullYear()
            width: 46
            height: 20
            radius: Theme.radius
            anchors.verticalCenter: parent.verticalCenter
            color: todayHover.hovered && away ? Theme.accent : Theme.surface0
            opacity: away ? 1 : 0.45
            Text {
                anchors.centerIn: parent
                text: "today"
                color: todayHover.hovered && todayBtn.away ? Theme.crust : Theme.text
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsXs
            }
            HoverHandler { id: todayHover; cursorShape: todayBtn.away ? Qt.PointingHandCursor : Qt.ArrowCursor }
            TapHandler {
                onTapped: {
                    root.shown = new Date(root.today.getFullYear(), root.today.getMonth(), 1)
                    root.picked = root.today
                }
            }
        }
        Item { width: 6; height: 1 }
        Text { text: "󰅁"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: Theme.fsXl; width: 30
            TapHandler { onTapped: root.shown = new Date(root.shown.getFullYear(), root.shown.getMonth() - 1, 1) } }
        Text { text: "󰅂"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: Theme.fsXl; width: 30
            TapHandler { onTapped: root.shown = new Date(root.shown.getFullYear(), root.shown.getMonth() + 1, 1) } }
    }

    Grid {
        columns: 7
        spacing: Theme.sp1
        Repeater {
            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            Text { required property string modelData; text: modelData; width: 34; horizontalAlignment: Text.AlignHCenter; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm }
        }
        Repeater {
            model: root.cells()
            Rectangle {
                id: cell
                required property int modelData
                readonly property date day: new Date(root.shown.getFullYear(), root.shown.getMonth(), Math.max(1, modelData))
                readonly property bool isToday: modelData === root.today.getDate() && root.shown.getMonth() === root.today.getMonth() && root.shown.getFullYear() === root.today.getFullYear()
                readonly property bool isPicked: modelData > 0 && Qt.formatDate(day, "yyyyMMdd") === Qt.formatDate(root.picked, "yyyyMMdd")
                readonly property bool busy: modelData > 0 && Agenda.onDay(day).length > 0
                width: 34
                height: 24
                radius: Theme.rSm
                color: isToday ? Theme.accent : (isPicked ? Theme.surface1 : (cellHover.hovered && modelData > 0 ? Theme.surface0 : "transparent"))
                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: cell.busy ? -2 : 0
                    text: cell.modelData > 0 ? cell.modelData : ""
                    color: cell.isToday ? Theme.crust : Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsMd
                }
                Rectangle {
                    visible: cell.busy
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3
                    width: 4
                    height: 4
                    radius: 2
                    color: cell.isToday ? Theme.crust : Theme.peach
                }
                HoverHandler { id: cellHover }
                TapHandler { onTapped: if (cell.modelData > 0) root.picked = cell.day }
            }
        }
    }

    Column {
        width: parent.width
        spacing: Theme.sp2
        topPadding: 6

        Text {
            visible: !Agenda.configured
            width: parent.width
            wrapMode: Text.WordWrap
            text: "No calendar yet: put your private iCal address in ~/.config/torus/calendar.url"
            color: Theme.overlay
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsSm
        }

        Text {
            visible: Agenda.configured && root.dayEvents.length === 0
            text: "Nothing on " + Qt.formatDate(root.picked, "ddd d MMM")
            color: Theme.overlay
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsSm
        }

        Repeater {
            model: root.dayEvents.slice(0, 3)
            Row {
                required property var modelData
                width: parent.width
                spacing: Theme.sp4
                Rectangle { width: 3; height: 14; radius: 2; color: Theme.peach; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: modelData.allDay ? "all day" : modelData.start.slice(11)
                    color: Theme.subtext
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fsXs
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    width: parent.width - x
                    text: modelData.title
                    color: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsMd
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Text {
            visible: root.dayEvents.length > 3
            text: "+" + (root.dayEvents.length - 3) + " more"
            color: Theme.overlay
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsXs
        }
    }
}
