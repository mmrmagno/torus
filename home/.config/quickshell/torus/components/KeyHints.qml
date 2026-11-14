import QtQuick
import QtQuick.Layouts
import qs

Flow {
    id: root

    property var hints: []
    Layout.preferredHeight: childrenRect.height
    spacing: Theme.sp6

    Repeater {
        model: root.hints
        Row {
            id: hint
            required property var modelData
            spacing: Theme.sp2
            Repeater {
                model: hint.modelData[0].split(" / ")
                Keycap {
                    required property string modelData
                    text: modelData
                    anchors.verticalCenter: hint.verticalCenter
                }
            }
            Text {
                text: hint.modelData[1]
                color: Theme.subtext
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsSm
                anchors.verticalCenter: hint.verticalCenter
            }
        }
    }
}
