import QtQuick
import QtQuick.Layouts
import qs
import qs.components

Rectangle {
    id: item

    property Item owner: null
    property var row: null
    property int rowIndex: 0
    readonly property bool current: owner !== null && owner.index === rowIndex
    readonly property bool binary: row !== null && row.values.length === 2 && row.values[1] === "on"
    readonly property string value: row && owner ? owner.value(row.key) : ""
    readonly property bool muted: row !== null && row.sub === true && owner !== null && owner.value("highlights") === "off"

    radius: Theme.rSm
    color: current ? Qt.alpha(Theme.accent, 0.14) : (rowHover.hovered ? Qt.alpha(Theme.surface0, 0.7) : "transparent")
    border.width: current ? 1 : 0
    border.color: Qt.alpha(Theme.accent, 0.5)
    opacity: muted ? 0.45 : 1
    Behavior on color { ColorAnimation { duration: Theme.durFast } }

    HoverHandler { id: rowHover }
    TapHandler { onTapped: if (item.owner) item.owner.index = item.rowIndex }

    RowLayout {
        anchors.fill: item
        anchors.leftMargin: item.row && item.row.sub ? 24 : 10
        anchors.rightMargin: 8
        spacing: Theme.sp5
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text { Layout.fillWidth: true; text: item.row ? item.row.label : ""; color: Theme.text; elide: Text.ElideRight; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd }
            Text { Layout.fillWidth: true; text: item.row ? item.row.note : ""; color: Theme.overlay; elide: Text.ElideRight; font.family: Theme.fontUi; font.pixelSize: Theme.fsXs }
        }
        Toggle {
            visible: item.binary
            activeFocusOnTab: false
            label: item.row ? item.row.label : ""
            checked: item.value === "on"
            onToggled: v => {
                item.owner.index = item.rowIndex
                item.owner.set(item.row.key, v ? "on" : "off")
            }
        }
        Segmented {
            visible: !item.binary
            activeFocusOnTab: false
            options: item.row && !item.binary ? item.row.values : []
            labels: item.row && item.row.labels ? item.row.labels : []
            current: item.value
            onPicked: v => {
                item.owner.index = item.rowIndex
                item.owner.set(item.row.key, v)
            }
        }
    }
}
