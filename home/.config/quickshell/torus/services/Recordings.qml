pragma Singleton
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string dir: Quickshell.env("XDG_VIDEOS_DIR") || Quickshell.env("HOME") + "/Videos"
    readonly property var latest: {
        const out = []
        for (let i = 0; i < Math.min(4, files.count); i++)
            out.push({ name: files.get(i, "fileName"), path: files.get(i, "filePath"), size: files.get(i, "fileSize"), date: files.get(i, "fileModified") })
        return out
    }
    readonly property int count: files.count

    Process {
        running: true
        command: ["mkdir", "-p", root.dir]
        onExited: files.folder = "file://" + root.dir
    }

    FolderListModel {
        id: files
        folder: ""
        nameFilters: ["torus-*.mp4", "Replay_*.mp4"]
        showDirs: false
        sortField: FolderListModel.Time
    }
}
