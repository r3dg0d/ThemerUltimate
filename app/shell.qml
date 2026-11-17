// ThemerUltimate: whole-desktop theme picker (Quickshell). Open: quickshell ipc -c themer-ultimate call themer open
// Cards come from `themer-ultimate list --json`; Apply runs `themer-ultimate apply <id>`, which rewrites the configs,
// reloads niri / waybar / mako / Ghostty / the wallpaper, and writes current.json, which every widget (this one
// included) watches through the Theme singleton, so the whole desktop restyles live.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root
    property bool opened: true
    property var themes: []
    property string busy: ""            // id being applied
    property string message: ""
    property int cursor: 0
    readonly property string home: Quickshell.env("HOME") || "/home/" + (Quickshell.env("USER") || "")
    readonly property string cli: home + "/.local/bin/themer-ultimate"
    readonly property string py: "/run/current-system/sw/bin/python3"
    readonly property var envv: ({
        HOME: home, USER: Quickshell.env("USER") || "",
        WAYLAND_DISPLAY: Quickshell.env("WAYLAND_DISPLAY") || "wayland-1",
        XDG_RUNTIME_DIR: Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000",
        NIRI_SOCKET: Quickshell.env("NIRI_SOCKET") || "",
        DBUS_SESSION_BUS_ADDRESS: Quickshell.env("DBUS_SESSION_BUS_ADDRESS") || "",
        PATH: home + "/.local/bin:" + home + "/.nix-profile/bin:/etc/profiles/per-user/" + (Quickshell.env("USER") || "") + "/bin:/run/current-system/sw/bin:/run/wrappers/bin" })
    readonly property string currentId: Theme.themeId

    function run(p, args) { p.environment = envv; p.command = [py, cli].concat(args); p.running = true }
    function refresh() { run(listP, ["list", "--json"]) }
    function apply(id) {
        if (busy) return
        busy = id; message = "applying " + id + "…"; run(applyP, ["apply", id])
    }
    Component.onCompleted: refresh()

    IpcHandler { target: "themer"
        function open(): void { root.opened = true; root.refresh() }
        function toggle(): void { root.opened = !root.opened; if (root.opened) root.refresh() }
        function close(): void { root.opened = false }
        function apply(id: string): void { root.apply(id) }
        function next(): void { if (root.themes.length) { const i = root.themes.findIndex(t => t.id === root.currentId); root.apply(root.themes[(i + 1) % root.themes.length].id) } } }

    Process { id: listP; stdout: StdioCollector { onStreamFinished: { try { root.themes = JSON.parse(text); const i = root.themes.findIndex(t => t.id === root.currentId); if (i >= 0) root.cursor = i } catch (e) { root.message = "could not list themes" } } } }
    Process { id: applyP
        stdout: StdioCollector { id: applyOut }
        stderr: StdioCollector { id: applyErr }
        onExited: (code) => { root.message = code === 0 ? "applied " + root.busy + " · the desktop restyled" : (applyErr.text.trim().split("\n").pop() || "apply failed"); root.busy = ""; root.refresh() } }

    component Small: Text { font.family: Theme.ui; color: Theme.label; font.pixelSize: 10; font.letterSpacing: 1.5 }

    FloatingWindow {
        id: win
        title: "ThemerUltimate"
        visible: root.opened
        implicitWidth: 1120; implicitHeight: 700
        minimumSize: Qt.size(900, 600)
        color: "transparent"
        onClosed: root.opened = false

        Nebula { anchors.fill: parent; radius: Theme.r(22); seed: 41; glow: 0.9 }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.opened = false
            Keys.onLeftPressed: root.cursor = Math.max(0, root.cursor - 1)
            Keys.onRightPressed: root.cursor = Math.min(root.themes.length - 1, root.cursor + 1)
            Keys.onReturnPressed: if (root.themes[root.cursor]) root.apply(root.themes[root.cursor].id)

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 26; spacing: 18

                RowLayout {
                    Layout.fillWidth: true; spacing: 14
                    Text { text: "󰏘"; font.family: Theme.icons; font.pixelSize: 30; color: Theme.primary }
                    ColumnLayout {
                        spacing: 2
                        Text { text: "ThemerUltimate"; font.family: Theme.ui; font.pixelSize: 24; font.weight: Font.DemiBold; color: Theme.ink }
                        Text { text: "one click rethemes niri, Ghostty, waybar, fuzzel, mako, GTK, the wallpaper and every Quickshell widget"
                               font.family: Theme.ui; font.pixelSize: 12; color: Theme.muted }
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        radius: Theme.r(14); color: Theme.surface; border.color: Theme.line; border.width: 1
                        implicitHeight: 34; implicitWidth: curRow.implicitWidth + 24
                        RowLayout { id: curRow; anchors.centerIn: parent; spacing: 8
                            Rectangle { width: 8; height: 8; radius: 4; color: Theme.ok }
                            Text { text: "ACTIVE · " + Theme.name.toUpperCase(); font.family: Theme.ui; font.pixelSize: 11; font.letterSpacing: 1.5; color: Theme.light } }
                    }
                    Rectangle {
                        implicitWidth: 34; implicitHeight: 34; radius: Theme.r(17)
                        color: closeMa.containsMouse ? Theme.raised : Theme.surface; border.color: Theme.line
                        Text { anchors.centerIn: parent; text: "󰅖"; font.family: Theme.icons; color: Theme.muted; font.pixelSize: 15 }
                        MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; onClicked: root.opened = false }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    columns: 4; columnSpacing: 16; rowSpacing: 16
                    Repeater {
                        model: root.themes
                        delegate: ThemeCard {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true; Layout.fillHeight: true
                            theme: modelData
                            active: modelData.id === root.currentId
                            focused: index === root.cursor
                            busy: root.busy === modelData.id
                            onPicked: root.apply(modelData.id)
                            onHoveredChanged: if (hovered) root.cursor = index
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Small { text: "←/→ pick · ENTER apply · ESC close · Mod+Alt+T toggles"; }
                    Item { Layout.fillWidth: true }
                    Text { text: root.message; font.family: Theme.code; font.pixelSize: 11; color: root.message.indexOf("fail") >= 0 ? Theme.err : Theme.muted; elide: Text.ElideLeft; Layout.maximumWidth: 560 }
                }
            }
        }
    }
}
