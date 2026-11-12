import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    id: root

    readonly property var list: ContainerWatch.list
    readonly property bool shown: list.length > 0

    cardEdges: Edges.Bottom | Edges.Right
    cardGravity: Edges.Bottom | Edges.Left
    icon: "󰡨"
    iconColor: Theme.sapphire
    label: String(list.length)
    onClicked: if (list.length > 0) ContainerWatch.logs(list[0])
    card: Component {
        Column {
            id: card
            spacing: Theme.sp3
            width: 420

            Text {
                text: "Containers"
                color: Theme.text
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsMd
                font.weight: Font.DemiBold
            }

            Repeater {
                model: root.list

                Column {
                    id: grp
                    required property var modelData
                    required property int index
                    readonly property bool first: index === 0 ? modelData.project !== "" : root.list[index - 1].project !== modelData.project
                    width: card.width

                RowLayout {
                    visible: grp.first
                    width: card.width
                    height: 24
                    Text {
                        Layout.fillWidth: true
                        text: grp.modelData.project || "Other"
                        color: Theme.overlay
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsXs
                        font.weight: Font.DemiBold
                        font.capitalization: Font.AllUppercase
                    }
                    Text {
                        visible: grp.modelData.project !== ""
                        text: "󰑓 restart project"
                        color: projArea.containsMouse ? Theme.accent : Theme.subtext
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsXs
                        MouseArea {
                            id: projArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ContainerWatch.restartProject(grp.modelData.engine, grp.modelData.project)
                        }
                    }
                }

                Rectangle {
                    id: srow
                    readonly property var modelData: grp.modelData
                    width: card.width
                    height: 48
                    radius: Theme.rCard
                    color: rowHover.hovered ? Theme.surface0 : "transparent"

                    HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: ContainerWatch.logs(srow.modelData)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 6
                        spacing: Theme.sp5

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                Layout.fillWidth: true
                                text: srow.modelData.name + "  ·  " + srow.modelData.image
                                color: Theme.text
                                font.family: Theme.fontUi
                                font.pixelSize: Theme.fsBase
                                elide: Text.ElideMiddle
                            }
                            Text {
                                Layout.fillWidth: true
                                text: srow.modelData.status + (srow.modelData.ports ? "  ·  " + srow.modelData.ports : "") + (srow.modelData.engine === "podman" ? "  ·  podman" : "")
                                color: Theme.subtext
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fsXs
                                elide: Text.ElideRight
                            }
                        }
                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: Theme.radius
                            color: restartArea.containsMouse ? Qt.alpha(Theme.accent, 0.25) : Theme.surface0
                            Text {
                                anchors.centerIn: parent
                                text: "󰑓"
                                color: Theme.accent
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fsBase
                            }
                            MouseArea {
                                id: restartArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ContainerWatch.act(srow.modelData, "restart")
                            }
                        }
                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: Theme.radius
                            color: stopArea.containsMouse ? Qt.alpha(Theme.red, 0.25) : Theme.surface0
                            Text {
                                anchors.centerIn: parent
                                text: "󰓛"
                                color: Theme.red
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fsBase
                            }
                            MouseArea {
                                id: stopArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ContainerWatch.act(srow.modelData, "stop")
                            }
                        }
                    }
                }
                }
            }

            Text {
                text: "click shows the logs, the arrow restarts, the square stops"
                color: Theme.overlay
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsXs
            }
        }
    }
}
