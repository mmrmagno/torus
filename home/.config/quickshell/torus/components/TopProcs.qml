import QtQuick
import Quickshell
import Quickshell.Io
import qs

Column {
    id: root

    property string sort: "cpu"
    property var rows: []
    spacing: 3
    width: 280

    Text {
        text: root.sort === "cpu" ? "Top processes" : "Top by memory"
        color: Theme.subtext
        font.family: Theme.fontUi
        font.pixelSize: 11
    }

    Repeater {
        model: root.rows
        Row {
            required property var modelData
            width: root.width
            Text { text: modelData[0]; color: Theme.text; font.family: Theme.fontMono; font.pixelSize: 11; width: parent.width - 90; elide: Text.ElideRight }
            Text { text: modelData[1]; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 11; width: 90; horizontalAlignment: Text.AlignRight }
        }
    }

    Process {
        id: ps
        command: ["sh", "-c", root.sort === "cpu"
            ? "top -b -n 2 -d 0.5 -w 200 -o %CPU | awk '/^top -/{n++} n==2 && $1 ~ /^[0-9]+$/ {print $12\"\\t\"$9\"%\"}' | head -5"
            : "ps -eo comm,rss --sort=-rss --no-headers | head -5 | awk '{printf \"%s\\t%.1fG\\n\", $1, $2/1048576}'"]
        stdout: StdioCollector {
            onStreamFinished: root.rows = text.trim().split("\n").filter(l => l).map(l => l.split("\t"))
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!ps.running) ps.running = true
    }
}
