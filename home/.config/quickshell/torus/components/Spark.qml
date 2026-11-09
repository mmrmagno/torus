import QtQuick
import qs

Canvas {
    id: root

    property var values: []
    property real max: 1
    property bool auto: false
    property color tint: Theme.accent
    property int slots: 30

    implicitHeight: 28
    onValuesChanged: requestPaint()
    onTintChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const v = values || []
        if (v.length < 2 || width <= 0)
            return
        const top = auto ? Math.max(1, ...v) * 1.15 : max
        const step = width / (slots - 1)
        const x0 = width - (v.length - 1) * step
        const y = val => height - 1 - Math.min(1, val / top) * (height - 3)
        ctx.beginPath()
        ctx.moveTo(x0, height)
        for (let i = 0; i < v.length; i++)
            ctx.lineTo(x0 + i * step, y(v[i]))
        ctx.lineTo(width, height)
        ctx.closePath()
        const g = ctx.createLinearGradient(0, 0, 0, height)
        g.addColorStop(0, Qt.alpha(tint, 0.35))
        g.addColorStop(1, Qt.alpha(tint, 0.02))
        ctx.fillStyle = g
        ctx.fill()
        ctx.beginPath()
        for (let i = 0; i < v.length; i++) {
            if (i === 0)
                ctx.moveTo(x0, y(v[0]))
            else
                ctx.lineTo(x0 + i * step, y(v[i]))
        }
        ctx.strokeStyle = tint
        ctx.lineWidth = 1.5
        ctx.lineJoin = "round"
        ctx.stroke()
    }
}
