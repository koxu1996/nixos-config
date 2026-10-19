// ChargeChart.qml: battery charge over the last 6 h (UPower history), 0–100 %.
// Lime line + area, shaded charging periods (dashed left edge + "CHARGING"), dashed amber
// line at 20 %, hour grid, "−6 h"/"now" labels, hover crosshair "54% · 2h 15m ago".
import QtQuick

Item {
    id: chart

    property var points: []   // [{ t, v, state }] oldest first (BatteryService.history)
    property real current: NaN // live percentage, appended as "now"
    property bool active: true
    readonly property int span: 21600 // s
    readonly property int chargingState: 1

    implicitHeight: 46 + axis.height + 4

    readonly property real now: Date.now() / 1000
    // History plus the live value, clipped to the window.
    readonly property var series: {
        const list = points.filter(p => p.t >= now - span);
        if (Number.isFinite(current)) list.push({ t: now, v: current, state: list.length ? list[list.length - 1].state : 0 });
        return list;
    }
    // Charging intervals [{ from, to }] (unix s).
    readonly property var chargingSpans: {
        const out = [];
        for (let i = 0; i < series.length - 1; i++)
            if (series[i].state === chargingState) {
                const last = out[out.length - 1];
                if (last && last.to === series[i].t) last.to = series[i + 1].t;
                else out.push({ from: series[i].t, to: series[i + 1].t });
            }
        return out;
    }

    function xFor(t) { return plot.width * (1 - (now - t) / span); }
    function yFor(v) { return plot.height - 2 - Math.max(0, Math.min(1, v / 100)) * (plot.height - 4); }

    onSeriesChanged: if (active) canvas.requestPaint()
    onActiveChanged: if (active) canvas.requestPaint()

    Rectangle {
        id: plot
        width: parent.width
        height: 46
        radius: Theme.radiusSmall
        color: Theme.inset
        clip: true

        // Charging shading + label.
        Repeater {
            model: chart.chargingSpans
            delegate: Rectangle {
                required property var modelData
                x: chart.xFor(modelData.from)
                width: Math.max(1, chart.xFor(modelData.to) - x)
                height: plot.height
                color: Theme.alpha(Theme.accent, 0.06)

                Text {
                    visible: parent.width > width + 6
                    x: 4
                    y: 3
                    text: "CHARGING"
                    color: Theme.alpha(Theme.accent, 0.7)
                    font.family: Theme.monoFont
                    font.pixelSize: 8
                    font.letterSpacing: 0.5
                }
            }
        }

        Canvas {
            id: canvas
            anchors.fill: parent

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const w = width, h = height;

                // Hour lines.
                ctx.lineWidth = 1;
                ctx.strokeStyle = Theme.borderSubtle;
                ctx.beginPath();
                for (let k = 1; k < 6; k++) {
                    const x = Math.round(w * (1 - k / 6)) + 0.5;
                    ctx.moveTo(x, 0); ctx.lineTo(x, h);
                }
                ctx.stroke();

                // Dashed left edges of charging periods.
                ctx.setLineDash([2, 2]);
                ctx.strokeStyle = Theme.alpha(Theme.accent, 0.5);
                ctx.beginPath();
                for (const s of chart.chargingSpans) {
                    const x = Math.round(chart.xFor(s.from)) + 0.5;
                    ctx.moveTo(x, 0); ctx.lineTo(x, h);
                }
                ctx.stroke();

                // 20 % low line.
                ctx.strokeStyle = Theme.warning;
                ctx.setLineDash([3, 3]);
                ctx.beginPath();
                const ly = Math.round(chart.yFor(20)) + 0.5;
                ctx.moveTo(0, ly); ctx.lineTo(w, ly);
                ctx.stroke();
                ctx.setLineDash([]);

                const s = chart.series;
                if (s.length < 2) return;
                const c = Theme.accent;

                ctx.beginPath();
                ctx.moveTo(chart.xFor(s[0].t), h);
                for (const p of s) ctx.lineTo(chart.xFor(p.t), chart.yFor(p.v));
                ctx.lineTo(chart.xFor(s[s.length - 1].t), h);
                ctx.closePath();
                ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.14);
                ctx.fill();

                ctx.beginPath();
                s.forEach((p, i) => i === 0 ? ctx.moveTo(chart.xFor(p.t), chart.yFor(p.v)) : ctx.lineTo(chart.xFor(p.t), chart.yFor(p.v)));
                ctx.lineWidth = 2;
                ctx.lineJoin = "round";
                ctx.strokeStyle = c;
                ctx.stroke();
            }
        }

        // ---- Hover ----
        MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true }

        readonly property int hoverIndex: {
            if (!hover.containsMouse || chart.series.length === 0) return -1;
            const t = chart.now - chart.span * (1 - hover.mouseX / width);
            let best = -1, bestD = Infinity;
            chart.series.forEach((p, i) => { const d = Math.abs(p.t - t); if (d < bestD) { bestD = d; best = i; } });
            return best;
        }
        readonly property var hoverPoint: hoverIndex >= 0 ? chart.series[hoverIndex] : null

        Rectangle {
            visible: plot.hoverPoint !== null
            x: Math.round(chart.xFor(plot.hoverPoint?.t ?? 0))
            width: 1
            height: plot.height
            color: Theme.textDisabled
        }

        Rectangle {
            visible: plot.hoverPoint !== null
            x: chart.xFor(plot.hoverPoint?.t ?? 0) - 3
            y: chart.yFor(plot.hoverPoint?.v ?? 0) - 3
            width: 6
            height: 6
            radius: 3
            color: Theme.accent
            border.width: 1
            border.color: Theme.raised
        }

        Rectangle {
            visible: plot.hoverPoint !== null
            readonly property real anchorX: chart.xFor(plot.hoverPoint?.t ?? 0)
            x: Math.max(0, Math.min(plot.width - width, anchorX + (anchorX > plot.width / 2 ? -width - 8 : 8)))
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
                text: {
                    const p = plot.hoverPoint;
                    if (!p) return "";
                    const ago = Math.max(0, Math.round(chart.now - p.t));
                    const h = Math.floor(ago / 3600), m = Math.floor((ago % 3600) / 60);
                    const when = ago < 60 ? "now" : h > 0 ? `${h}h ${m}m ago` : `${m}m ago`;
                    return `${Math.round(p.v)}% · ${when}`;
                }
                color: Theme.textPrimary
                font.family: Theme.monoFont
                font.pixelSize: Theme.fontSizeSmall
                font.features: { "tnum": 1 }
            }
        }
    }

    // Axis labels.
    Item {
        id: axis
        y: plot.height + 4
        width: parent.width
        height: left.implicitHeight

        Text {
            id: left
            text: "−6 h"
            color: Theme.textDisabled
            font.family: Theme.monoFont
            font.pixelSize: Theme.fontSizeSmall
        }

        Text {
            anchors.right: parent.right
            text: "now"
            color: Theme.textDisabled
            font.family: Theme.monoFont
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
