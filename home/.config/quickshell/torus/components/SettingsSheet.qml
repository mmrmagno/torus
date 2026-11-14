import QtQuick
import QtQuick.Layouts
import qs

Rectangle {
    id: sheet

    property string title: ""
    property string note: ""
    property string glyph: "󰒓"
    property var rows: []
    property var values: ({})
    property int index: 0
    default property alias extra: extraBox.data
    signal picked(string key, string value)
    signal closed()
    signal deletePressed()
    onVisibleChanged: Store.sheetTitle = visible ? title : ""
    property var moreHints: []

    function value(key) {
        const v = values[key]
        return v === undefined ? "" : String(v)
    }

    function set(key, v) {
        if (value(key) === v)
            return
        Store.sound("tick")
        picked(key, v)
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
            set(r.key, value(r.key) === r.values[1] ? r.values[0] : r.values[1])
        else
            change(1)
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
        else if (event.key === Qt.Key_Delete)
            deletePressed()
        return true
    }

    radius: Theme.rPanel
    color: Theme.base
    border.width: 1
    border.color: Qt.alpha(Theme.accent, 0.35)
    MouseArea {
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onWheel: wheel => wheel.accepted = true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 22
        spacing: Theme.sp5

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp5
            Text { text: sheet.glyph; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 22 }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text { Layout.fillWidth: true; text: sheet.title; color: Theme.text; elide: Text.ElideRight; font.family: Theme.fontUi; font.pixelSize: Theme.fsTitle; font.weight: Font.DemiBold }
                Text { Layout.fillWidth: true; visible: text !== ""; text: sheet.note; color: Theme.subtext; elide: Text.ElideRight; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm }
            }
            Rectangle {
                id: closeBtn
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 15
                color: closeHover.hovered ? Theme.surface1 : Theme.surface0
                Text { anchors.centerIn: closeBtn; text: "󰅖"; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fsMd }
                HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: closeBtn; onClicked: sheet.closed() }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.sp2
            Repeater {
                model: sheet.rows
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
        }

        ColumnLayout {
            id: extraBox
            Layout.fillWidth: true
            spacing: Theme.sp4
        }

        Item { Layout.fillHeight: true }

        KeyHints {
            Layout.fillWidth: true
            hints: [["↑ / ↓", "pick"], ["← / →", "change"], ["Space", "switch"]].concat(sheet.moreHints).concat([["Esc", "back"]])
        }
    }
}
