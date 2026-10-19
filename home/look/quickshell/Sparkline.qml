// Sparkline.qml: tiny line + area chart of the last `samples` values on a fixed scale.
import QtQuick

Rectangle {
    id: spark

    property var values: []
    property real maxValue: 100
    property color lineColor: Theme.accent
    property int samples: 30

    implicitWidth: 38
    implicitHeight: 16
    radius: 3
    color: Theme.hover

    onValuesChanged: canvas.requestPaint()
    onMaxValueChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        anchors.margins: 1

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const data = spark.values.slice(-spark.samples);
            if (data.length < 2) return;
            const w = width, h = height, step = w / (spark.samples - 1);
            const x0 = w - (data.length - 1) * step;
            const y = v => h - 0.75 - Math.max(0, Math.min(1, v / spark.maxValue)) * (h - 1.5);
            const c = spark.lineColor;

            ctx.beginPath();
            ctx.moveTo(x0, h);
            data.forEach((v, i) => ctx.lineTo(x0 + i * step, y(v)));
            ctx.lineTo(w, h);
            ctx.closePath();
            ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.35);
            ctx.fill();

            ctx.beginPath();
            data.forEach((v, i) => i === 0 ? ctx.moveTo(x0, y(v)) : ctx.lineTo(x0 + i * step, y(v)));
            ctx.lineWidth = 1.5;
            ctx.lineJoin = "round";
            ctx.strokeStyle = c;
            ctx.stroke();
        }
    }
}
