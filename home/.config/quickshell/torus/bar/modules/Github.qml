import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services

Chip {
    id: root

    readonly property bool shown: GitHub.wanted > 0
    readonly property var rows: GitHub.review.map(p => ({ glyph: "󰈈", color: Theme.accent, title: p.title, sub: p.repo + " #" + p.number + "  ·  " + p.author + "  ·  " + GitHub.ago(p.updated), url: p.url, head: "Review requests" }))
        .concat(GitHub.failing.map(r => ({ glyph: "󰅚", color: Theme.red, title: r.repo, sub: r.branch + " is failing  ·  " + GitHub.ago(r.updated), url: r.url, head: "Failing on the main branch" })))
        .concat(GitHub.mine.map(p => ({ glyph: p.ci === "failure" || p.ci === "error" ? "󰅚" : p.ci === "pending" ? "󰔟" : p.ci === "success" ? "󰄬" : "󰘬", color: p.ci === "failure" || p.ci === "error" ? Theme.red : p.ci === "pending" ? Theme.yellow : p.ci === "success" ? Theme.green : Theme.overlay, title: p.title, sub: p.repo + " #" + p.number + (p.draft ? "  ·  draft" : "") + "  ·  " + GitHub.ago(p.updated), url: p.url, head: "My pull requests" })))

    cardEdges: Edges.Bottom | Edges.Right
    cardGravity: Edges.Bottom | Edges.Left
    icon: "󰊤"
    iconColor: GitHub.failing.length + GitHub.redCi > 0 ? Theme.red : Theme.accent
    label: String(GitHub.wanted)
    onClicked: GitHub.open(GitHub.review.length > 0 ? "https://github.com/pulls/review-requested" : "https://github.com/pulls")
    card: Component {
        Column {
            id: card
            spacing: Theme.sp2
            width: 420

            Text {
                text: "GitHub" + (GitHub.login ? "  ·  " + GitHub.login : "")
                color: Theme.text
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsMd
                font.weight: Font.DemiBold
            }

            Repeater {
                model: root.rows.slice(0, 10)

                Column {
                    id: grow
                    required property var modelData
                    required property int index
                    readonly property bool first: index === 0 || root.rows[index - 1].head !== modelData.head
                    width: card.width

                    Text {
                        visible: grow.first
                        height: 22
                        verticalAlignment: Text.AlignBottom
                        bottomPadding: 3
                        text: grow.modelData.head
                        color: Theme.overlay
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.fsXs
                        font.weight: Font.DemiBold
                        font.capitalization: Font.AllUppercase
                    }

                    Rectangle {
                        width: card.width
                        height: 44
                        radius: Theme.rCard
                        color: rowHover.hovered ? Theme.surface0 : "transparent"

                        HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: GitHub.open(grow.modelData.url)
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: Theme.sp5

                            Text {
                                Layout.preferredWidth: 20
                                text: grow.modelData.glyph
                                color: grow.modelData.color
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fsLg
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    Layout.fillWidth: true
                                    text: grow.modelData.title
                                    color: Theme.text
                                    font.family: Theme.fontUi
                                    font.pixelSize: Theme.fsBase
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: grow.modelData.sub
                                    color: Theme.subtext
                                    font.family: Theme.fontUi
                                    font.pixelSize: Theme.fsXs
                                    elide: Text.ElideMiddle
                                }
                            }
                        }
                    }
                }
            }

            Text {
                text: (root.rows.length > 10 ? (root.rows.length - 10) + " more under gh in SUPER+Space, " : "") + "click opens it, the chip opens your review queue"
                color: Theme.overlay
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsXs
            }
        }
    }
}
