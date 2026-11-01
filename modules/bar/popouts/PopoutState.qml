import QtQuick

QtObject {
    property string currentName
    property bool hasCurrent
    // Window preview payload used by the workspace hover popout.
    property var windowPreviewClient
    property Item windowPreviewTrigger

    signal detachRequested(mode: string)
}
