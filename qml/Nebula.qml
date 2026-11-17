import QtQuick

// ThemerUltimate window backdrop, shared by every widget (canonical copy: ThemerUltimate/qml/Nebula.qml, linked
// into each widget folder). Solid fill + soft clouds + sparse stars (+ optional digital rain) + a lit rim, all
// painted into ONE Canvas raster that repaints only on resize or theme change. Colours and strengths come from
// Theme (current.json); with Purple Nebula it paints exactly the original Purple Galaxy backdrop.
// No Gradient on a rounded Rectangle anywhere: the scene graph interpolates those per triangle and shows a seam.
Item {
    id: neb
    property real radius: Theme.r(22)  // callers pass Theme.r(n) too
    property int seed: 7               // vary per widget so siblings don't share a sky
    property real stars: 1.0           // star density multiplier (times Theme.glowStars)
    property real glow: 1.0            // nebula strength multiplier (times Theme.glowNebula; 0 = plain fill)
    property color fill: Theme.window
    property bool rim: true
    property bool hot: false           // brighter rim (focus / live state)
    onHotChanged: sky.requestPaint()
    onGlowChanged: sky.requestPaint()
    onRadiusChanged: sky.requestPaint()
    onFillChanged: sky.requestPaint()
    Connections { target: Theme; function onRevisionChanged() { sky.requestPaint() } }

    Canvas {
        id: sky
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const c = getContext("2d"); c.reset()
            const w = width, h = height, r = Math.min(neb.radius, w / 2, h / 2)
            if (w < 4 || h < 4) return
            const T = Theme
            const acc = T.rgb(T.accent), pri = T.rgb(T.primary), hot = T.rgb(T.hot), sink = T.rgb(T.sink)
            const lit = T.rgb(T.light), ink = T.rgb(T.ink)
            c.beginPath(); c.roundedRect(0.5, 0.5, w - 1, h - 1, r, r); c.closePath()
            c.save(); c.clip()
            c.fillStyle = neb.fill; c.fillRect(0, 0, w, h)

            let s = neb.seed * 7919 + 13
            const rnd = () => { s = (s * 16807) % 2147483647; return s / 2147483647 }
            const big = Math.max(w, h), k = neb.glow * T.glowNebula
            const blob = (fx, fy, fr, rgb, a) => {
                if (a * k <= 0) return
                const x = w * fx, y = h * fy, rr = big * fr
                const g = c.createRadialGradient(x, y, 0, x, y, rr)
                g.addColorStop(0, "rgba(" + rgb + "," + (a * k).toFixed(3) + ")")
                g.addColorStop(0.55, "rgba(" + rgb + "," + (a * k * 0.35).toFixed(3) + ")")
                g.addColorStop(1, "rgba(" + rgb + ",0)")
                c.fillStyle = g; c.fillRect(0, 0, w, h)
            }
            // main clouds: deep accent core top-left, primary bottom-right, a faint hot wisp, a deep sink
            blob(0.08 + rnd() * 0.15, 0.02 + rnd() * 0.12, 0.62, acc, 0.15)
            blob(0.80 + rnd() * 0.15, 0.82 + rnd() * 0.15, 0.55, pri, 0.10)
            blob(0.70 + rnd() * 0.2, 0.10 + rnd() * 0.2, 0.32, hot, 0.055)
            blob(0.25 + rnd() * 0.3, 0.75 + rnd() * 0.2, 0.40, sink, 0.08)
            // dust lane: small puffs along a gentle diagonal
            const lane = 7, y0 = 0.25 + rnd() * 0.2, y1 = 0.6 + rnd() * 0.2
            for (let i = 0; i < lane; ++i) {
                const t = i / (lane - 1)
                blob(t, y0 + (y1 - y0) * t + (rnd() - 0.5) * 0.08, 0.10 + rnd() * 0.08, i % 2 ? pri : lit, 0.035)
            }
            // stars
            const n = Math.round(w * h / 7000 * neb.stars * T.glowStars)
            for (let i = 0; i < n; ++i) {
                const x = rnd() * w, y = rnd() * h, roll = rnd()
                if (roll > 0.985) {            // sparkle: soft halo + thin cross
                    const hg = c.createRadialGradient(x, y, 0, x, y, 7)
                    hg.addColorStop(0, "rgba(" + lit + ",0.45)"); hg.addColorStop(1, "rgba(" + lit + ",0)")
                    c.fillStyle = hg; c.fillRect(x - 7, y - 7, 14, 14)
                    c.fillStyle = "rgba(" + ink + ",0.55)"
                    c.fillRect(x - 4, y - 0.5, 8, 1); c.fillRect(x - 0.5, y - 4, 1, 8)
                } else if (roll > 0.93) {
                    c.fillStyle = "rgba(" + lit + "," + (0.35 + rnd() * 0.3).toFixed(2) + ")"
                    c.fillRect(x, y, 1.6, 1.6)
                } else {
                    c.fillStyle = "rgba(" + ink + "," + (0.08 + rnd() * 0.22).toFixed(2) + ")"
                    c.fillRect(x, y, 1, 1)
                }
            }
            // digital rain: faint glyph columns with a bright head (H4X0R); off for other themes
            if (T.glowRain > 0) {
                const glyphs = "01ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ0123456789"
                const fs = 13, cols = Math.floor(w / fs)
                c.font = fs + "px \"" + T.code + "\""
                for (let col = 0; col < cols; ++col) {
                    if (rnd() > 0.38) continue
                    const len = 6 + Math.floor(rnd() * 18), head = Math.floor(rnd() * (h / fs + len))
                    for (let j = 0; j < len; ++j) {
                        const row = head - j; if (row < 0 || row * fs > h) continue
                        const a = (j === 0 ? 0.55 : 0.22 * (1 - j / len)) * T.glowRain
                        c.fillStyle = "rgba(" + (j === 0 ? lit : pri) + "," + a.toFixed(3) + ")"
                        c.fillText(glyphs[Math.floor(rnd() * glyphs.length)], col * fs + 2, row * fs)
                    }
                }
            }
            c.restore()
            if (!neb.rim) return
            // rim: base edge colour, lit from the top-left like the nebula core
            c.beginPath(); c.roundedRect(0.5, 0.5, w - 1, h - 1, r, r); c.closePath()
            c.lineWidth = 1
            c.strokeStyle = neb.hot ? T.edgeHot : T.edgeSoft; c.stroke()
            const rk = T.glowRim
            if (rk <= 0) return
            const lg = c.createRadialGradient(w * 0.22, 0, 0, w * 0.22, 0, Math.max(w, h) * 0.75)
            lg.addColorStop(0, neb.hot ? "rgba(" + lit + "," + (0.85 * rk) + ")" : "rgba(" + T.rgb(T.rimGlow) + "," + (0.6 * rk) + ")")
            lg.addColorStop(0.5, "rgba(" + acc + "," + (0.25 * rk) + ")")
            lg.addColorStop(1, "rgba(" + acc + ",0)")
            c.strokeStyle = lg; c.stroke()
        }
    }
}
