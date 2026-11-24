import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

Rectangle {
    id: sheet

    property string status: ""
    property bool busy: false
    property string removing: ""
    signal closed
    signal changed

    function open() {
        status = ""
        removing = ""
        pw.text = ""
        Music.loadServers()
        if (Music.servers.length === 0 && name.text === "")
            name.text = "StreamFin"
        const first = Music.servers.length === 0 ? addr : folder
        first.editor.forceActiveFocus()
        folder.text = Music.folder
    }

    function save() {
        if (busy)
            return
        if (!name.text.trim() || !addr.text.trim() || !user.text.trim() || !pw.text) {
            status = "Name, address, user and app password are all needed"
            sayShake.go()
            return
        }
        busy = true
        status = "Testing " + addr.text.trim() + " ..."
        const secret = pw.text
        pw.text = ""
        Music.run(["login", name.text.trim(), addr.text.trim(), user.text.trim()], m => {
            busy = false
            if (m.error) {
                status = m.error
                sayShake.go()
                return
            }
            status = m.name + " works" + (m.opensubsonic ? " (OpenSubsonic)" : "") + ", the password is in the keyring"
            addr.text = ""
            user.text = ""
            name.text = ""
            Music.loadServers(() => sheet.changed())
        }, secret)
    }

    function remove(n) {
        if (removing !== n) {
            removing = n
            status = "Remove " + n + "? Click again, its password leaves the keyring too"
            return
        }
        removing = ""
        Music.run(["logout", n], () => {
            status = n + " removed"
            Music.loadServers(() => sheet.changed())
        })
    }

    function test(n) {
        status = "Testing " + n + " ..."
        Music.run(["test", n], m => status = m.error ? m.error : n + " answers")
    }

    function setFolder() {
        Music.run(["folder", folder.text.trim()], m => {
            status = m.error ? m.error : "Scanning " + folder.text.trim() + " in the background"
            if (!m.error)
                Music.loadServers(() => sheet.changed())
        })
    }

    color: Theme.base
    radius: Theme.rPanel
    onVisibleChanged: Store.sheetTitle = visible ? "Music settings" : ""
    Keys.onEscapePressed: sheet.closed()

    MouseArea {
        anchors.fill: parent
        z: -1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 22
        spacing: Theme.sp6

        RowLayout {
            Layout.fillWidth: true
            Text { text: "󰒓"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: Theme.fsTitle }
            Text { Layout.fillWidth: true; text: "Music settings"; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsTitle; font.weight: Font.DemiBold }
            PanelButton { icon: "󰅖"; implicitHeight: 28; activeFocusOnTab: false; onClicked: sheet.closed() }
        }

        Text { text: "Servers"; color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; font.weight: Font.DemiBold }
        Text {
            visible: Music.servers.length === 0
            text: "None yet. Any Subsonic or OpenSubsonic server works: StreamFin on Jellyfin, Navidrome, Gonic."
            color: Theme.overlay
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsSm
        }
        Repeater {
            model: Music.servers
            RowLayout {
                id: srv
                required property var modelData
                Layout.fillWidth: true
                spacing: Theme.sp5
                Text { text: "󰒋"; color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: Theme.fsLg }
                Text { text: srv.modelData.name; color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.fsMd; font.weight: Font.DemiBold }
                Text { Layout.fillWidth: true; text: srv.modelData.url + ", " + srv.modelData.user; elide: Text.ElideMiddle; color: Theme.overlay; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm }
                PanelButton { implicitHeight: 28; label: "Test"; onClicked: sheet.test(srv.modelData.name) }
                PanelButton { implicitHeight: 28; label: sheet.removing === srv.modelData.name ? "Remove for good" : "Remove"; active: sheet.removing === srv.modelData.name; onClicked: sheet.remove(srv.modelData.name) }
            }
        }

        Text { Layout.topMargin: Theme.sp4; text: "Add a server"; color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; font.weight: Font.DemiBold }
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Theme.sp5
            rowSpacing: Theme.sp4
            MusicField { id: name; Layout.fillWidth: true; label: "Name"; hint: "StreamFin"; onSubmitted: sheet.save() }
            MusicField { id: addr; Layout.fillWidth: true; label: "Address"; hint: "https://jellyfin.example/StreamFin"; onSubmitted: sheet.save() }
            MusicField { id: user; Layout.fillWidth: true; label: "User"; hint: "your Jellyfin user"; onSubmitted: sheet.save() }
            MusicField { id: pw; Layout.fillWidth: true; label: "Password"; hint: "app password, not your login"; secret: true; onSubmitted: sheet.save() }
        }
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: "StreamFin: settings, Subsonic apps, New password. It goes to the keyring, never a file."
                wrapMode: Text.WordWrap
                color: Theme.overlay
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsXs
            }
            PanelButton { icon: "󰄬"; label: sheet.busy ? "Testing" : "Test and save"; onClicked: sheet.save() }
        }

        Text { Layout.topMargin: Theme.sp4; text: "Local library"; color: Theme.subtext; font.family: Theme.fontUi; font.pixelSize: Theme.fsSm; font.weight: Font.DemiBold }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp5
            MusicField { id: folder; Layout.fillWidth: true; label: "Folder"; hint: "~/Music"; onSubmitted: sheet.setFolder() }
            Text {
                text: Music.indexing ? "scanning ..." : Music.localCount + " tracks"
                color: Theme.overlay
                font.family: Theme.fontUi
                font.pixelSize: Theme.fsSm
            }
            PanelButton { icon: "󰑓"; label: "Rescan"; onClicked: sheet.setFolder() }
        }

        Item { Layout.fillHeight: true }

        Text {
            Layout.fillWidth: true
            visible: sheet.status !== ""
            transform: Translate { id: sayNudge }
            Shake { id: sayShake; nudge: sayNudge; by: 6 }
            text: sheet.status
            wrapMode: Text.WordWrap
            color: /refused|wrong|offline|needed|not|error|HTTP|must/i.test(sheet.status) ? Theme.peach : Theme.green
            font.family: Theme.fontUi
            font.pixelSize: Theme.fsSm
        }
        KeyHints {
            Layout.fillWidth: true
            hints: [["Tab", "next field"], ["↵", "test and save"], ["Esc", "back"]]
        }
    }
}
