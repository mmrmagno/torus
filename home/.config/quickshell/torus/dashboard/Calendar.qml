import QtQuick
import Quickshell
import qs

Column {
    id: root
    property date shown: new Date()
    readonly property var today: clock.date
    spacing: 6

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
            width: parent.width - 60
            text: Qt.formatDate(root.shown, "MMMM yyyy")
            color: Theme.text
            font.family: Theme.fontUi
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
        Text { text: "󰅁"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 16; width: 30
            TapHandler { onTapped: root.shown = new Date(root.shown.getFullYear(), root.shown.getMonth() - 1, 1) } }
        Text { text: "󰅂"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 16; width: 30
            TapHandler { onTapped: root.shown = new Date(root.shown.getFullYear(), root.shown.getMonth() + 1, 1) } }
    }

    Grid {
        columns: 7
        spacing: 2
        Repeater {
            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            Text { required property string modelData; text: modelData; width: 34; horizontalAlignment: Text.AlignHCenter; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: 11 }
        }
        Repeater {
            model: root.cells()
            Rectangle {
                required property int modelData
                readonly property bool isToday: modelData === root.today.getDate() && root.shown.getMonth() === root.today.getMonth() && root.shown.getFullYear() === root.today.getFullYear()
                width: 34
                height: 26
                radius: 8
                color: isToday ? Theme.accent : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: parent.modelData > 0 ? parent.modelData : ""
                    color: parent.isToday ? Theme.crust : Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: 12
                }
            }
        }
    }
}
