pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import M3Shapes
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.utils

Item {
    id: root

    required property int modelData
    required property int index
    required property int activeWsId
    required property int ws
    required property HyprlandMonitor monitor

    required property int displayType
    required property bool showWindows
    required property var iconRules
    property string activeLabel
    property string occupiedLabel
    property string label

    readonly property list<HyprlandToplevel> toplevels: Hypr.toplevelsForWs(ws, GlobalConfig.bar.workspaces.ignoredTags)
    readonly property bool isOccupied: toplevels.length > 0
    readonly property bool hasWindows: isOccupied && showWindows && Config.bar.workspaces.maxWindowIcons > 0
    readonly property bool focused: activeWsId === ws
    readonly property list<int> focusedShapeList: [MaterialShape.Slanted, MaterialShape.Oval, MaterialShape.Pill, MaterialShape.Triangle, MaterialShape.Arrow, MaterialShape.Diamond, MaterialShape.Pentagon, MaterialShape.Gem, MaterialShape.VerySunny, MaterialShape.Sunny, MaterialShape.Cookie4Sided, MaterialShape.Cookie6Sided, MaterialShape.Cookie7Sided, MaterialShape.Cookie9Sided, MaterialShape.Cookie12Sided, MaterialShape.Clover4Leaf, MaterialShape.SoftBurst, MaterialShape.Ghostish]

    property color offMonitorColour: Colours.palette.m3outlineVariant
    readonly property bool onOtherMonitor: {
        if (Config.bar.workspaces.perMonitor)
            return false;
        const mon = Hypr.workspaces.values.find(w => w.id === ws)?.monitor;
        return !!(mon && mon !== monitor);
    }
    readonly property color fgColour: {
        if (onOtherMonitor)
            return offMonitorColour;
        if (focused || isOccupied || Config.bar.workspaces.occupiedBg)
            return Colours.palette.m3onSurface;
        return Colours.layer(Colours.palette.m3outlineVariant, 2);
    }

    function updateShape(): void {
        const shape = indicator.item as MaterialShape;
        if (!shape)
            return;

        if (focused)
            shape.shape = focusedShapeList[Math.floor(Math.random() * focusedShapeList.length)];
        else
            shape.shape = Qt.binding(() => isOccupied ? MaterialShape.Square : MaterialShape.Circle);
    }

    anchors.horizontalCenter: parent?.horizontalCenter
    LazyListView.preferredHeight: LazyListView.removing ? 0 : layout.implicitHeight + (hasWindows ? Tokens.padding.extraSmall : 0)
    LazyListView.visibleHeight: LazyListView.preferredHeight

    opacity: LazyListView.removing || LazyListView.adding ? 0 : 1

    onFocusedChanged: updateShape()
    Component.onCompleted: updateShape()

    Behavior on LazyListView.visibleHeight {
        Anim {}
    }

    Behavior on y {
        enabled: root.LazyListView.ready

        Anim {}
    }

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    Component {
        id: shapeComponent

        MaterialShape {
            implicitSize: Tokens.sizes.bar.innerWidth - Tokens.padding.small

            color: root.fgColour
            scale: root.focused ? 2 / 3 : root.isOccupied ? 1 / 3 : 1 / 4

            animationEasing: Tokens.anim.expressiveDefaultSpatial
            animationDuration: Tokens.anim.durations.expressiveDefaultSpatial * Tokens.anim.durations.scale

            Behavior on color {
                CAnim {}
            }

            Behavior on scale {
                Anim {}
            }
        }
    }

    Component {
        id: textComponent

        StyledText {
            animate: true
            text: {
                if (root.focused) {
                    const label = root.activeLabel;
                    if (label)
                        return label;
                }

                if (root.focused || root.isOccupied) {
                    const label = root.occupiedLabel;
                    if (label)
                        return label;
                }

                const label = root.label;
                if (label)
                    return label;

                const ws = Hypr.workspaces.values.find(w => w.id === root.ws);
                const wsName = !ws || ws.name == root.ws ? root.ws : Hypr.trimWsName(ws.name)[0];

                const capitalisation = Config.bar.workspaces.capitalisation;
                if (capitalisation === BarWorkspaceCapitalisation.Upper)
                    return String(wsName).toUpperCase();
                else if (capitalisation === BarWorkspaceCapitalisation.Lower)
                    return String(wsName).toLowerCase();
                return wsName;
            }
            color: root.fgColour
            verticalAlignment: Qt.AlignVCenter
            font.family: Tokens.font.workspaces
        }
    }

    Component {
        id: iconComponent

        MaterialIcon {
            fill: 1
            grade: 25
            text: iconCacher.icon
            color: root.fgColour
            verticalAlignment: Qt.AlignVCenter

            WsIconCacher {
                id: iconCacher
            }
        }
    }

    Component {
        id: iconLoaderComponent

        Loader {
            sourceComponent: loaderIconCacher.icon ? iconComponent : textComponent

            WsIconCacher {
                id: loaderIconCacher
            }
        }
    }

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: 0

        Loader {
            id: indicator

            Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
            Layout.preferredHeight: Tokens.sizes.bar.innerWidth - Tokens.padding.small
            sourceComponent: {
                if (root.displayType === BarWorkspaceDisplay.Icons)
                    return iconLoaderComponent;
                if (root.displayType === BarWorkspaceDisplay.Text)
                    return textComponent;
                return shapeComponent;
            }

            onItemChanged: root.updateShape()
        }

        Loader {
            id: windows

            asynchronous: true

            Layout.fillWidth: true
            Layout.topMargin: -Tokens.spacing.extraSmall / 2
            Layout.preferredHeight: root.hasWindows && item ? (item as LazyListView).layoutHeight : 0

            visible: active
            active: root.showWindows && Config.bar.workspaces.maxWindowIcons > 0

            sourceComponent: LazyListView {
                spacing: 0
                implicitHeight: contentHeight
                cullDelegates: false
                removeDuration: Tokens.anim.durations.expressiveDefaultEffects

                model: ScriptModel {
                    values: {
                        const windows = root.toplevels;
                        const maxIcons = root.Config.bar.workspaces.maxWindowIcons;
                        return maxIcons > 0 ? windows.slice(0, maxIcons) : windows;
                    }
                }

                delegate: MaterialIcon {
                    id: windowButton

                    required property var modelData
                    required property int index // Needed, LazyListView will fail to set it if it doesn't exist

                    property bool previewOpen: false
                    property bool previewHovered: false

                    grade: 0
                    horizontalAlignment: Text.AlignHCenter
                    text: Icons.getAppCategoryIcon(modelData.lastIpcObject.class, "terminal")
                    color: iconMouse.containsMouse ? Colours.palette.m3primary : root.onOtherMonitor ? root.offMonitorColour : Colours.palette.m3onSurfaceVariant

                    opacity: LazyListView.adding || LazyListView.removing ? 0 : 1

                    Behavior on color {
                        CAnim {}
                    }

                    Behavior on opacity {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }

                    Behavior on y {
                        Anim {}
                    }

                    function focusWindow(): void {
                        const address = String(modelData.address || "");
                        if (!address)
                            return;

                        if (String(modelData.lastIpcObject.workspace?.name || "") === "special:minimized") {
                            const activeWorkspaceId = Number(Hypr.focusedMonitor?.lastIpcObject.activeWorkspace?.id ?? 0);
                            const workspace = Hypr.workspaces.values.find(w => w.id === activeWorkspaceId && w.id > 0)
                                ?? Hypr.workspaces.values.find(w => w.id > 0 && w.monitor === Hypr.focusedMonitor?.name)
                                ?? Hypr.workspaces.values.find(w => w.id > 0);
                            const target = workspace?.id ?? 1;
                            Hypr.dispatch(Hypr.usingLua
                                ? `hl.dsp.window.move({workspace=${target},follow=true,window="address:${address}"})`
                                : `movetoworkspace ${target},address:${address}`);
                            Qt.callLater(() => Hypr.focusWindow(address));
                        } else {
                            Hypr.focusWindow(address);
                        }
                    }

                    function minimizeWindow(): void {
                        const address = String(modelData.address || "");
                        if (!address)
                            return;
                        Hypr.dispatch(Hypr.usingLua
                            ? `hl.dsp.window.move({workspace="special:minimized",follow=false,window="address:${address}"})`
                            : `movetoworkspacesilent special:minimized,address:${address}`);
                    }

                    function closeWindow(): void {
                        const address = String(modelData.address || "");
                        if (!address)
                            return;
                        Hypr.dispatch(Hypr.usingLua
                            ? `hl.dsp.window.close({window="address:${address}"})`
                            : `closewindow address:${address}`);
                    }

                    MouseArea {
                        id: iconMouse
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onEntered: {
                            hidePreviewTimer.stop();
                            windowButton.previewOpen = true;
                        }
                        onExited: hidePreviewTimer.restart()
                        onClicked: event => {
                            if (event.button === Qt.RightButton)
                                contextMenu.expanded = true;
                            else
                                windowButton.focusWindow();
                        }

                        Menu {
                            id: contextMenu

                            attachTo: windowButton
                            attachSideX: Menu.Right
                            thisSideX: Menu.Right
                            attachSideY: Menu.Bottom
                            thisSideY: Menu.Top
                            items: [minimizeItem, closeItem]

                            MenuItem {
                                id: minimizeItem
                                text: Tr.tr("Minimize")
                                icon: "minimize"
                                onClicked: windowButton.minimizeWindow()
                            }

                            MenuItem {
                                id: closeItem
                                text: Tr.tr("Close")
                                icon: "close"
                                onClicked: windowButton.closeWindow()
                            }
                        }
                    }

                    Timer {
                        id: hidePreviewTimer
                        interval: 180
                        onTriggered: {
                            if (!iconMouse.containsMouse && !windowButton.previewHovered)
                                windowButton.previewOpen = false;
                        }
                    }

                    PopupWindow {
                        id: preview

                        anchor.item: windowButton
                        anchor.edges: Edges.Right
                        anchor.gravity: Edges.Right
                        anchor.adjustment: PopupAdjustment.All
                        implicitWidth: 270
                        implicitHeight: 190
                        visible: windowButton.previewOpen
                        color: "transparent"

                        StyledRect {
                            anchors.fill: parent
                            anchors.margins: Tokens.padding.extraSmall
                            radius: Tokens.rounding.large
                            color: Colours.palette.m3surfaceContainer
                            clip: true
                            border.width: 1
                            border.color: Colours.palette.m3outlineVariant
                            opacity: preview.visible ? 1 : 0
                            scale: preview.visible ? 1 : 0.96

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 120
                                    easing.type: Easing.OutCubic
                                    alwaysRunToEnd: true
                                }
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 120
                                    easing.type: Easing.OutCubic
                                    alwaysRunToEnd: true
                                }
                            }

                            Elevation {
                                anchors.fill: parent
                                radius: Tokens.rounding.large
                                level: 3
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Tokens.padding.small
                                spacing: Tokens.spacing.extraSmall

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Tokens.spacing.small

                                    MaterialIcon {
                                        text: windowButton.text
                                        color: Colours.palette.m3primary
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: windowButton.modelData.title || windowButton.modelData.lastIpcObject.class || Tr.tr("Window")
                                        color: Colours.palette.m3onSurface
                                        elide: Text.ElideRight
                                    }
                                }

                                ClipRect {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    color: Colours.palette.m3surfaceContainerHighest
                                    radius: Tokens.rounding.medium

                                    ScreencopyView {
                                        id: screencopy
                                        anchors.fill: parent
                                        anchors.margins: Tokens.padding.extraSmall
                                        captureSource: preview.visible ? windowButton.modelData.wayland : null
                                        live: preview.visible
                                        constraintSize: Qt.size(250, 145)
                                    }

                                    Loader {
                                        anchors.centerIn: parent
                                        active: !screencopy.hasContent

                                        sourceComponent: StyledText {
                                            text: Tr.tr("Preview unavailable")
                                            color: Colours.palette.m3onSurfaceVariant
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                            onEntered: {
                                windowButton.previewHovered = true;
                                hidePreviewTimer.stop();
                            }
                            onExited: {
                                windowButton.previewHovered = false;
                                hidePreviewTimer.restart();
                            }
                        }
                    }
                }
            }
        }
    }

    component WsIconCacher: QtObject {
        id: cacher

        property string name
        readonly property string icon: Icons.matchIconRuleList(Hypr.trimWsName(name), root.iconRules)
        readonly property HyprlandWorkspace wsObj: Hypr.workspaces.values.find(w => w.id === root.ws) ?? null

        readonly property Connections conn: Connections {
            function onNameChanged(): void {
                cacher.updateName();
            }

            target: cacher.wsObj
        }

        function updateName(): void {
            if (wsObj)
                name = wsObj.name;
        }

        onWsObjChanged: updateName()
        Component.onCompleted: updateName()
    }
}
