import QtQuick

QtObject {
    property string currentName
    property bool hasCurrent
    // Window preview payload used by the workspace hover popout.
    property var windowPreviewClient

    signal detachRequested(mode: string)
}
