pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services

// Presents the focused application's AT-SPI menubar to the Caelestia bar.
// The helper only snapshots while the optional feature is enabled.
Singleton {
    id: root

    property list<var> entries: []
    property string appTitle: ""
    property int pid: 0
    property int openMenuIndex: -1
    property int openSubmenuIndex: -1
    property int openNestedSubmenuIndex: -1
    property bool requestPending: false
    property string entriesKey: ""

    readonly property string helper: Quickshell.shellPath("scripts/caelestia-appmenu.py")

    function refresh(): void {
        if (!WindowDecorSettings.appMenuEnabled) {
            root.requestPending = false;
            return;
        }
        if (probe.running) {
            root.requestPending = true;
            return;
        }
        root.requestPending = false;
        probe.running = true;
    }

    function closeMenus(): void {
        root.openMenuIndex = -1;
        root.openSubmenuIndex = -1;
        root.openNestedSubmenuIndex = -1;
    }

    function applySnapshot(value: string): void {
        if (!WindowDecorSettings.appMenuEnabled)
            return;
        try {
            const data = JSON.parse(value);
            const nextPid = Number(data.pid) || 0;
            const nextTitle = String(data.title || "");
            const nextEntries = Array.isArray(data.entries) ? data.entries : [];
            const shellClass = String(data.class || "").toLowerCase();
            const shellTookFocus = ["quickshell", "org.quickshell", "qs"].includes(shellClass)
                || ["quickshell", "org.quickshell", "qs"].includes(nextTitle.toLowerCase());

            // Clicking the shell menu can make its surface active. Keep the
            // source application's menu alive until the user dismisses it.
            if (root.openMenuIndex >= 0 && (nextPid === 0 || shellTookFocus))
                return;

            const nextKey = JSON.stringify(nextEntries);
            const changed = nextPid !== root.pid || nextKey !== root.entriesKey;
            root.pid = nextPid;
            root.appTitle = nextTitle;
            root.entries = nextEntries;
            root.entriesKey = nextKey;
            if (changed) {
                root.openMenuIndex = -1;
                root.openSubmenuIndex = -1;
                root.openNestedSubmenuIndex = -1;
            }
        } catch (error) {
            console.warn("Caelestia appmenu: invalid accessibility snapshot", error);
            root.entries = [];
        }
    }

    function activate(item: var): void {
        if (!WindowDecorSettings.appMenuEnabled || !item)
            return;
        if (item.kind === "hyprland") {
            const window = item.address;
            if (!window)
                return;
            if (item.action === "close")
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.close({window="${window}"})` : `closewindow ${window}`);
            else if (item.action === "minimize")
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.move({workspace="special:minimized",follow=false,window="${window}"})` : `movetoworkspacesilent special:minimized,${window}`);
            else if (item.action === "fullscreen")
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.fullscreen({mode="maximized",action="toggle",window="${window}"})` : `fullscreen 1 ${window}`);
            else if (item.action === "floating")
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.float({window="${window}"})` : `togglefloating ${window}`);
        } else if (item.path && root.pid > 0) {
            if (menuAction.running)
                return;
            const command = ["/usr/bin/python3", root.helper, "click", String(root.pid), String(item.path)];
            menuAction.command = command;
            menuAction.running = true;
            root.closeMenus();
            return;
        } else {
            return;
        }
        root.closeMenus();
    }

    function enableQtAccessibility(): void {
        Quickshell.execDetached(["hyprctl", "eval", 'hl.env("QT_LINUX_ACCESSIBILITY_ALWAYS_ON", "1")']);
    }

    Process {
        id: probe

        command: ["/usr/bin/python3", root.helper]
        stdout: StdioCollector {
            onStreamFinished: {
                root.applySnapshot(text);
                if (WindowDecorSettings.appMenuEnabled && root.pid > 0)
                    Quickshell.execDetached(["/usr/bin/python3", root.helper, "native-menu", "hide", String(root.pid)]);
            }
        }
        onExited: {
            if (root.requestPending)
                Qt.callLater(root.refresh);
        }
    }

    Process {
        id: menuAction

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                root.closeMenus();
            else
                console.warn("Caelestia appmenu: AT-SPI activation failed", exitCode, exitStatus);
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event): void {
            if (WindowDecorSettings.appMenuEnabled && (event.name === "activewindow" || event.name === "activewindowv2"))
                root.refresh();
        }
    }

    Connections {
        target: WindowDecorSettings
        function onAppMenuEnabledChanged(): void {
            if (WindowDecorSettings.appMenuEnabled) {
                root.enableQtAccessibility();
                root.refresh();
            } else {
                Quickshell.execDetached(["/usr/bin/python3", root.helper, "native-menu", "restore"]);
                root.entries = [];
                root.entriesKey = "";
                root.appTitle = "";
                root.pid = 0;
                root.openMenuIndex = -1;
                root.openSubmenuIndex = -1;
                root.openNestedSubmenuIndex = -1;
            }
        }
    }

    Timer {
        interval: 3000
        repeat: true
        running: WindowDecorSettings.appMenuEnabled
        onTriggered: root.refresh()
    }
}
