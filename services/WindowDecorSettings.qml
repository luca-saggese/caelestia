pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// Persistent opt-in for the native Hyprland floating-window decoration.
Singleton {
    id: root

    readonly property string path: `${Paths.config}/window-decor.json`
    property bool loaded: false
    property bool enabled: false
    property bool appMenuEnabled: false
    property list<string> managedFloating: []

    function setEnabled(value: bool): void {
        if (!root.loaded)
            return;
        root.enabled = value;
        root.write();
    }

    function setAppMenuEnabled(value: bool): void {
        if (!root.loaded)
            return;
        root.appMenuEnabled = value;
        root.write();
    }

    function rememberFloating(address: string): void {
        if (!address || root.managedFloating.includes(address))
            return;
        root.managedFloating = [...root.managedFloating, address];
        root.write();
    }

    function clearManagedFloating(): void {
        root.managedFloating = [];
        root.write();
    }

    function write(): void {
        if (root.loaded)
            storage.setText(JSON.stringify({
                enabled: root.enabled,
                appMenuEnabled: root.appMenuEnabled,
                managedFloating: root.managedFloating
            }, null, 4) + "\n");
    }

    FileView {
        id: storage

        path: root.path
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.enabled = data.enabled ?? false;
                root.appMenuEnabled = data.appMenuEnabled ?? false;
                root.managedFloating = data.managedFloating ?? [];
            } catch (e) {
                console.warn("Window decoration settings are invalid; using defaults", e);
            }
            root.loaded = true;
        }
        onLoadFailed: err => {
            root.loaded = true;
            if (err === FileViewError.FileNotFound)
                Qt.callLater(() => root.write());
        }
    }
}
