import QtQuick
import qs

Rectangle {
    id: root

    // each option: { value, label }; host is the panel frame the list opens over
    property var options: []
    property var list: []
    property string known: ""
    property string current: ""
    property string hint: ""
    property Item host: null
    property real most: 320
    property bool opened: false
    property Item back: null
    property string query: ""
    property int index: 0
    signal picked(string value)

    // audio nodes come and go with every short sound: only a real change may touch an open list
    onOptionsChanged: {
        const s = JSON.stringify(options)
        if (s === known)
            return
        const at = opened && shown[index] ? shown[index].value : null
        known = s
        list = options
        if (at !== null)
            index = Math.max(0, shown.findIndex(o => o.value === at))
    }
    readonly property bool choice: list.length > 1
    readonly property bool searching: list.length > 5
    readonly property string label: {
        const o = list.find(x => x.value === current)
        return o ? o.label : hint
    }
    readonly property var shown: {
        const words = searching ? query.trim().toLowerCase().split(/\s+/).filter(w => w) : []
        return list.filter(o => words.every(w => o.label.toLowerCase().includes(w)))
    }

    function show() {
        if (!choice || !host || opened)
            return
        query = ""
        back = Window.activeFocusItem || root
        index = Math.max(0, list.findIndex(o => o.value === current))
        opened = true
        Store.picker = { label: label, rows: () => shown.map(o => o.label), index: () => index, box: () => layer.item ? layer.item.where() : "" }
    }

    function hide() {
        if (!opened)
            return
        opened = false
        Store.picker = null
        if (back)
            back.forceActiveFocus()
    }

    function choose(o) {
        hide()
        if (o && o.value !== current)
            picked(o.value)
    }

    onVisibleChanged: if (!visible) hide()
    Component.onDestruction: if (opened) {
        Store.picker = null
        if (back && back !== root)
            back.forceActiveFocus()
        else if (host)
            host.forceActiveFocus()
    }
    onQueryChanged: if (searching) index = query === "" ? Math.max(0, list.findIndex(o => o.value === current)) : 0
    activeFocusOnTab: visible && choice
    onActiveFocusChanged: if (activeFocus) Store.focusLabel = label
    Keys.onReturnPressed: root.show()
    Keys.onEnterPressed: root.show()
    Keys.onSpacePressed: root.show()
    Keys.onDownPressed: root.show()
    implicitHeight: 30
    implicitWidth: Math.min(most, text.implicitWidth + (choice ? 46 : 24))
    radius: height / 2
    color: choice && (area.containsMouse || opened) ? Theme.surface1 : choice ? Theme.surface0 : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.durFast } }
    scale: area.pressed && choice ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }

    FocusRing { on: root.activeFocus; baseRadius: root.radius }

    Text {
        id: text
        anchors.left: parent.left
        anchors.leftMargin: root.choice ? 14 : 0
        anchors.right: root.choice ? chevron.left : parent.right
        anchors.rightMargin: root.choice ? 8 : 0
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        elide: Text.ElideRight
        color: Theme.text
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsMd
    }
    Text {
        id: chevron
        visible: root.choice
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: "󰅀"
        color: Theme.subtext
        font.family: Theme.fontMono
        font.pixelSize: Theme.fsMd
        rotation: root.opened ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.choice ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.opened ? root.hide() : root.show()
    }

    // mouse areas only in here: a TapHandler would hand the click on to whatever the list covers
    Loader {
        id: layer
        parent: root.host || root
        anchors.fill: parent
        z: 200
        active: root.opened && root.host !== null
        sourceComponent: Item {
            id: sheet

            Keys.onPressed: event => event.accepted = true

            function where() {
                const p = box.mapToItem(null, 0, 0)
                return Math.round(p.x) + "," + Math.round(p.y) + "," + Math.round(box.width) + "," + Math.round(box.height) + "," + list.y
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                hoverEnabled: true
                onPressed: root.hide()
                onWheel: wheel => wheel.accepted = true
            }

            Rectangle {
                id: box
                readonly property point at: root.opened ? root.mapToItem(sheet, 0, 0) : Qt.point(0, 0)
                readonly property real below: sheet.height - at.y - root.height - 14
                readonly property real above: at.y - 14
                readonly property real want: 12 + (searchRow.visible ? searchRow.height + 4 : 0) + Math.max(34, Math.min(7, root.shown.length) * 34)
                readonly property bool up: want > below && above > below
                width: Math.min(sheet.width - 16, Math.max(root.width, 260))
                height: Math.min(want, up ? above : below)
                x: Math.max(8, Math.min(sheet.width - width - 8, at.x))
                y: up ? at.y - height - 6 : at.y + root.height + 6
                radius: Theme.rSm + 2
                color: Theme.mantle
                border.width: 1
                border.color: Qt.alpha(Theme.accent, 0.35)
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

                property real p: 0
                Component.onCompleted: {
                    p = 1
                    search.forceActiveFocus()
                    list.positionViewAtIndex(root.index, ListView.Contain)
                }
                Behavior on p { NumberAnimation { duration: Theme.durFast; easing.type: Easing.OutCubic } }
                opacity: p
                scale: 0.97 + 0.03 * p
                transformOrigin: up ? Item.Bottom : Item.Top

                Item {
                    id: searchRow
                    visible: root.searching
                    x: 6
                    y: 6
                    width: parent.width - 12
                    height: 32
                    Text { x: 8; anchors.verticalCenter: parent.verticalCenter; text: "󰍉"; color: Theme.overlay; font.family: Theme.fontMono; font.pixelSize: Theme.fsMd }
                    Text {
                        x: 30
                        visible: search.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Type to find one of " + root.list.length
                        color: Theme.overlay
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsMd
                    }
                }
                TextInput {
                    id: search
                    x: 36
                    y: 6
                    width: parent.width - 48
                    height: 32
                    opacity: searchRow.visible ? 1 : 0
                    enabled: true
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsMd
                    clip: true
                    onTextChanged: root.query = text
                    onActiveFocusChanged: if (!activeFocus) Qt.callLater(root.hide)
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape)
                            root.hide()
                        else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab)
                            root.index = Math.max(0, Math.min(root.shown.length - 1, root.index + 1))
                        else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab)
                            root.index = Math.max(0, root.index - 1)
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                            root.choose(root.shown[root.index])
                        else
                            return
                        event.accepted = true
                        list.positionViewAtIndex(root.index, ListView.Contain)
                    }
                }

                ListView {
                    id: list
                    x: 6
                    y: searchRow.visible ? 42 : 6
                    width: parent.width - 12
                    height: parent.height - y - 6
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.shown
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        width: list.width
                        height: 34
                        radius: Theme.rXs + 2
                        color: index === root.index ? Qt.alpha(Theme.accent, 0.18) : "transparent"
                        Text {
                            x: 10
                            width: parent.width - 40
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.label
                            elide: Text.ElideRight
                            color: Theme.text
                            font.family: Theme.fontUi
                            font.pixelSize: Theme.fsMd
                        }
                        Text {
                            visible: row.modelData.value === root.current
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "󰄬"
                            color: Theme.accent
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fsMd
                        }
                        Press { target: row; down: rowArea.pressed }
                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            anchors.margins: pressed ? -3 : 0
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: root.index = row.index
                            onClicked: root.choose(row.modelData)
                        }
                    }
                }
                Text {
                    visible: root.shown.length === 0
                    anchors.centerIn: list
                    text: "Nothing matches"
                    color: Theme.overlay
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.fsMd
                }
            }
        }
    }
}
