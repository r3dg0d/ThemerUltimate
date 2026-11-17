import QtQuick
import QtQuick.Layouts

// One theme: swatches + a mini desktop drawn in that theme's own colours, so you see it before applying.
// The card chrome itself follows the current Theme. Solid fills only (no vertical gradient in rounded rects).
Rectangle {
    id: card
    property var theme: ({})
    property bool active: false
    property bool focused: false
    property bool busy: false
    readonly property bool hovered: ma.containsMouse
    signal picked()
    readonly property var c: theme.colors || ({})
    readonly property var fo: theme.fonts || ({})
    readonly property real rs: theme.shape && theme.shape.radiusScale !== undefined ? theme.shape.radiusScale : 1
    function tr(n) { return Math.round(n * rs) }

    radius: Theme.r(18)
    color: hovered ? Theme.raised : Theme.surface
    border.width: active ? 2 : 1
    border.color: active ? Theme.primary : (focused || hovered) ? Theme.edgeHot : Theme.line
    Behavior on color { ColorAnimation { duration: 140 } }
    implicitHeight: 520

    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: card.picked() }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 14; spacing: 12

        // ---- mini desktop in the theme's own colours
        Rectangle {
            id: mock
            Layout.fillWidth: true; Layout.preferredHeight: 250
            radius: Theme.r(12); clip: true
            color: card.c.void || "#000"
            border.color: card.c.line || "#333"; border.width: 1
            // wallpaper hint: a soft accent glow (or a flat page for light themes)
            Rectangle { anchors.fill: parent; anchors.margins: 1; radius: parent.radius; color: card.c.base || "#000"; opacity: 0.6 }
            Repeater {
                model: card.theme.glow && card.theme.glow.rain > 0 ? 14 : 0
                Text { required property int index
                    x: 6 + index * (mock.width / 14); y: 30 + (index * 37) % 120
                    text: "ｱ0ﾊ1\nﾐ1ﾋ\n0ｰｳ\n1ｼ"; lineHeight: 0.8
                    font.family: card.fo.code || "monospace"; font.pixelSize: 9
                    color: card.c.primary || "#0f0"; opacity: 0.22 }
            }
            Rectangle { // nebula glow blob
                visible: (card.theme.glow && card.theme.glow.nebula || 0) > 0
                width: mock.width * 0.9; height: width; radius: width / 2
                x: -width * 0.25; y: -height * 0.45
                color: card.c.accent || "#000"; opacity: 0.18 * (card.theme.glow ? card.theme.glow.nebula : 0)
            }
            // top bar: pills
            Row {
                x: 8; y: 7; spacing: 5
                Repeater { model: [26, 54, 36]
                    Rectangle { required property var modelData; required property int index
                        width: modelData; height: 14; radius: Math.min(7, card.tr(7) + (card.theme.shape && card.theme.shape.pill > 100 ? 7 : 0))
                        color: card.c.surface || "#111"; border.color: card.c.line || "#222"; border.width: 1
                        Rectangle { visible: index === 1; anchors.centerIn: parent; width: 30; height: 4; radius: 2; color: card.c.light || "#fff" } } }
            }
            Rectangle { anchors.right: parent.right; anchors.rightMargin: 8; y: 7; width: 46; height: 14
                radius: Math.min(7, card.tr(7) + (card.theme.shape && card.theme.shape.pill > 100 ? 7 : 0))
                color: card.c.surface || "#111"; border.color: card.c.line || "#222"
                Text { anchors.centerIn: parent; text: "12:34"; font.family: card.fo.led || "monospace"; font.pixelSize: 8; color: card.c.bright || "#fff" } }
            // terminal window with focus ring
            Rectangle {
                x: 10; y: 30; width: mock.width * 0.6; height: mock.height - 42
                radius: card.tr(10)
                color: card.theme.terminal ? card.theme.terminal.background : "#000"
                border.width: 2; border.color: card.theme.focusRing ? card.theme.focusRing.from : "#fff"
                Column {
                    x: 9; y: 8; spacing: 3
                    Text { text: "❯ themer-ultimate apply " + (card.theme.id || ""); font.family: card.fo.terminal || "monospace"; font.pixelSize: 9
                           color: card.theme.terminal ? card.theme.terminal.foreground : "#fff" }
                    Row { spacing: 3
                        Repeater { model: card.theme.terminal ? card.theme.terminal.palette.slice(0, 8) : []
                            Rectangle { required property var modelData; width: 13; height: 8; radius: 1; color: modelData } } }
                    Repeater { model: [0.9, 0.6, 0.75, 0.4, 0.8]
                        Rectangle { required property var modelData; required property int index
                            width: (mock.width * 0.6 - 24) * modelData; height: 4; radius: 2
                            color: index % 2 ? (card.c.muted || "#888") : (card.c.primary || "#fff"); opacity: 0.8 } }
                    Text { text: card.theme.terminal && card.theme.terminal.shader ? "shader · " + card.theme.terminal.shader.replace(".glsl", "") : "shader · none"
                           font.family: card.fo.terminal || "monospace"; font.pixelSize: 8; color: card.c.dim || "#666" }
                }
            }
            // a widget panel
            Rectangle {
                anchors.right: parent.right; anchors.rightMargin: 10; y: 30
                width: mock.width * 0.34 - 14; height: mock.height - 42
                radius: card.tr(14); color: card.c.window || "#000"; border.color: card.c.edgeSoft || "#333"; border.width: 1
                Column {
                    anchors.fill: parent; anchors.margins: 8; spacing: 6
                    Text { text: "HUB"; font.family: card.fo.ui || "sans"; font.pixelSize: 8; font.letterSpacing: 1.2; color: card.c.label || "#888" }
                    Text { text: "21°"; font.family: card.fo.led || "monospace"; font.pixelSize: 20; color: card.c.ink || "#fff" }
                    Rectangle { width: parent.width; height: 5; radius: 2.5; color: card.c.raised || "#222"
                        Rectangle { width: parent.width * 0.62; height: parent.height; radius: 2.5; color: card.c.primary || "#fff" } }
                    Rectangle { width: parent.width; height: 18; radius: card.tr(9); color: card.c.primary || "#fff"
                        Text { anchors.centerIn: parent; text: "Apply"; font.family: card.fo.ui || "sans"; font.pixelSize: 8; color: card.c.void || "#000" } }
                    Rectangle { width: parent.width; height: 18; radius: card.tr(9); color: card.c.surface || "#111"; border.color: card.c.line || "#222"
                        Text { anchors.centerIn: parent; text: "Cancel"; font.family: card.fo.ui || "sans"; font.pixelSize: 8; color: card.c.light || "#ccc" } }
                }
            }
        }

        // ---- name + tagline
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Text { text: card.theme.name || ""; font.family: card.fo.ui || Theme.ui; font.pixelSize: 19; font.weight: Font.DemiBold; color: Theme.ink; Layout.fillWidth: true; elide: Text.ElideRight }
            Rectangle {
                visible: card.active; radius: Theme.r(9); color: Theme.okBg; border.color: Theme.ok; border.width: 1
                implicitWidth: actT.implicitWidth + 16; implicitHeight: 20
                Text { id: actT; anchors.centerIn: parent; text: "ACTIVE"; font.family: Theme.ui; font.pixelSize: 9; font.letterSpacing: 1.5; color: Theme.ok }
            }
        }
        Text { Layout.fillWidth: true; text: card.theme.tagline || ""; wrapMode: Text.WordWrap; font.family: Theme.ui; font.pixelSize: 12; color: Theme.muted; maximumLineCount: 3; elide: Text.ElideRight }

        // ---- swatches
        Row {
            spacing: 6
            Repeater {
                model: ["void", "surface", "raised", "accent", "primary", "light", "hot", "ink", "ok", "red"]
                Rectangle { required property var modelData; width: 18; height: 18; radius: Math.max(2, card.tr(9))
                    color: card.c[modelData] || "#000"; border.color: Theme.line; border.width: 1 }
            }
        }
        Text {
            Layout.fillWidth: true; elide: Text.ElideRight
            text: (card.fo.ui || "") + " · " + (card.fo.led || "") + " · " + (card.fo.terminal || "") + (card.theme.mode === "light" ? " · light" : " · dark")
            font.family: Theme.code; font.pixelSize: 10; color: Theme.dim
        }
        Item { Layout.fillHeight: true }

        // ---- apply
        Rectangle {
            Layout.fillWidth: true; implicitHeight: 40; radius: Theme.r(14)
            color: card.active ? Theme.surface : applyMa.pressed ? Theme.accent : applyMa.containsMouse ? Theme.light : Theme.primary
            border.color: card.active ? Theme.line : "transparent"; border.width: 1
            Behavior on color { ColorAnimation { duration: 120 } }
            Text { anchors.centerIn: parent
                text: card.busy ? "applying…" : card.active ? "✓ applied" : "Apply " + (card.theme.name || "")
                font.family: Theme.ui; font.pixelSize: 14; font.weight: Font.DemiBold
                color: card.active ? Theme.muted : Theme.void_ }
            MouseArea { id: applyMa; anchors.fill: parent; hoverEnabled: true; enabled: !card.active && !card.busy; onClicked: card.picked() }
        }
    }
}
