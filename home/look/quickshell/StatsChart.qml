// StatsChart.qml: 5-minute chart (300 one-second samples, newest on the right) with a
// minute grid, a midline, an optional dashed threshold, and a hover crosshair + tooltip
// ("7.9 GB · 2m 14s ago"). Repaints only while `active`.
import QtQuick

Rectangle {
    id: chart

    property var values: []
    property real minValue: 0
    property real maxValue: 100
    property color lineColor: Theme.accent
    property real threshold: NaN          // dashed line value (e.g. warm temperature)
    property color thresholdColor: Theme.warning
    property var format: v => `${Math.round(v)}`
    property bool active: true
    readonly property int slots: StatsService.historyLength

    implicitHeight: 46
    radius: Theme.radiusSmall
    color: Theme.inset

    onValuesChanged: if (active) canvas.requestPaint()
    onActiveChanged: if (active) canvas.requestPaint()
    onLineColorChanged: canvas.requestPaint()

    function xFor(i, count) { return width - (count - 1 - i) * (width / (slots - 1)); }
    function yFor(v) {
        const t = (v - minValue) / (maxValue - minValue);
        return height - 2 - Math.max(0, Math.min(1, t)) * (height - 4);
    }

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height, data = chart.values;
            const grid = Theme.borderSubtle;

            // Minute lines (every 60 samples from the newest) and the midline.
            ctx.lineWidth = 1;
            ctx.strokeStyle = grid;
            ctx.beginPath();
            for (let s = 60; s < chart.slots; s += 60) {
                const x = Math.round(w - s * (w / (chart.slots - 1))) + 0.5;
                ctx.moveTo(x, 0); ctx.lineTo(x, h);
            }
            ctx.moveTo(0, Math.round(h / 2) + 0.5); ctx.lineTo(w, Math.round(h / 2) + 0.5);
            ctx.stroke();

            if (!isNaN(chart.threshold)) {
                const ty = Math.round(chart.yFor(chart.threshold)) + 0.5;
                ctx.setLineDash([3, 3]);
                ctx.strokeStyle = chart.thresholdColor;
                ctx.beginPath(); ctx.moveTo(0, ty); ctx.lineTo(w, ty); ctx.stroke();
                ctx.setLineDash([]);
            }

            if (data.length < 2) return;
            const c = chart.lineColor;
            const n = data.length;

            ctx.beginPath();
            ctx.moveTo(chart.xFor(0, n), h);
            data.forEach((v, i) => ctx.lineTo(chart.xFor(i, n), chart.yFor(v)));
            ctx.lineTo(w, h);
            ctx.closePath();
            ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.14);
            ctx.fill();

            ctx.beginPath();
            data.forEach((v, i) => i === 0 ? ctx.moveTo(chart.xFor(0, n), chart.yFor(v)) : ctx.lineTo(chart.xFor(i, n), chart.yFor(v)));
            ctx.lineWidth = 2;
            ctx.lineJoin = "round";
            ctx.strokeStyle = c;
            ctx.stroke();
        }
    }

    // ---- Hover: crosshair + tooltip ----
    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
    }

    // Index of the sample under the cursor (-1 if none there yet).
    readonly property int hoverIndex: {
        if (!hover.containsMouse || values.length === 0) return -1;
        const fromEnd = Math.round((width - hover.mouseX) / (width / (slots - 1)));
        const i = values.length - 1 - fromEnd;
        return i >= 0 ? i : -1;
    }

    Rectangle {
        visible: chart.hoverIndex >= 0
        x: Math.round(chart.xFor(chart.hoverIndex, chart.values.length))
        width: 1
        height: parent.height
        color: Theme.textDisabled
    }

    Rectangle {
        visible: chart.hoverIndex >= 0
        x: chart.xFor(chart.hoverIndex, chart.values.length) - width / 2
        y: chart.yFor(chart.values[chart.hoverIndex] ?? 0) - height / 2
        width: 6
        height: 6
        radius: 3
        color: chart.lineColor
        border.width: 1
        border.color: Theme.raised
    }

    Rectangle {
        id: tip
        visible: chart.hoverIndex >= 0
        z: 2
        readonly property real anchorX: chart.xFor(chart.hoverIndex, chart.values.length)
        x: Math.max(0, Math.min(chart.width - width, anchorX + (anchorX > chart.width / 2 ? -width - 8 : 8)))
        y: 3
        width: tipText.implicitWidth + 12
        height: tipText.implicitHeight + 6
        radius: Theme.radiusSmall
        color: Theme.raisedHigh
        border.width: Theme.borderWidth
        border.color: Theme.border

        Text {
            id: tipText
            anchors.centerIn: parent
            text: chart.hoverIndex >= 0
                ? `${chart.format(chart.values[chart.hoverIndex])} · ${StatsService.ago(chart.values.length - 1 - chart.hoverIndex)}`
                : ""
            color: Theme.textPrimary
            font.family: Theme.monoFont
            font.pixelSize: Theme.fontSizeSmall
            font.features: { "tnum": 1 }
        }
    }
}
