import QtQuick
import QtMultimedia
import Quickshell.Widgets
import qs

Item {
    id: view

    property string path: ""

    MediaPlayer {
        id: player
        source: view.path !== "" ? "file://" + view.path : ""
        videoOutput: screen
        audioOutput: AudioOutput {}
        loops: MediaPlayer.Infinite
        onSourceChanged: if (view.path !== "") play()
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: Theme.rCard
        color: Theme.crust
        VideoOutput {
            id: screen
            anchors.fill: parent
            fillMode: VideoOutput.PreserveAspectFit
        }
    }

    Text {
        visible: player.error !== MediaPlayer.NoError
        anchors.centerIn: parent
        text: "This clip cannot be played"
        color: Theme.subtext
        font.family: Theme.fontUi
        font.pixelSize: Theme.fsMd
    }
}
