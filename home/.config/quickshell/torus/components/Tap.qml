import QtQuick

TapHandler {
    id: tap

    property Item on: parent
    property bool quiet: false
    property real reach: 0
    // the item shrinks under the pointer, its edge must still count when the button comes up
    margin: reach + (pressed ? 6 : 0)

    property Press dip: Press { target: tap.on; down: tap.pressed && !tap.quiet }
}
