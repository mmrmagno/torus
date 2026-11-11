import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    id: root

    readonly property var list: DevServers.servers
    readonly property bool shown: list.length > 0

    cardEdges: Edges.Bottom | Edges.Right
    cardGravity: Edges.Bottom | Edges.Left
    icon: "󰒋"
    iconColor: Theme.green
    label: list.length === 1 ? ":" + list[0].port : (list.length > 1 ? String(list.length) : "")
    onClicked: if (list.length > 0) DevServers.open(list[0])
    card: Component {
        Column {
            id: card
            spacing: Theme.sp3
            width: 380

            Text {
                text: "Dev servers"
                color: Theme.text
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsMd
                font.weight: Font.DemiBold
            }

            Repeater {
                model: root.list

                Rectangle {
                    id: srow
                    required property var modelData
                    width: card.width
                    height: 48
                    radius: Theme.rCard
                    color: rowHover.hovered ? Theme.surface0 : "transparent"

                    HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: DevServers.open(srow.modelData)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 6
                        spacing: Theme.sp5

                        Text {
                            Layout.preferredWidth: 62
                            text: ":" + srow.modelData.port
                            color: Theme.accent
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fsLg
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                Layout.fillWidth: true
                                text: srow.modelData.comm + (srow.modelData.cwd ? "  ·  " + DevServers.tilde(srow.modelData.cwd) : "")
                                color: Theme.text
                                font.family: Theme.fontUi
                                font.pixelSize: Theme.fsBase
                                elide: Text.ElideMiddle
                            }
                            Text {
                                Layout.fillWidth: true
                                text: srow.modelData.cmd
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
                                onClicked: DevServers.stop(srow.modelData)
                            }
                        }
                    }
                }
            }

            Text {
                text: "click opens it in the browser, the square stops it"
                color: Theme.overlay
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsXs
            }
        }
    }
}
