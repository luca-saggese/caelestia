import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// Content for the normal Caelestia popout: the frame BlobGroup paints its
// attached background and the popout wrapper owns its geometry/hit testing.
Item {
    id: root

    readonly property var topItem: AppMenu.entries[AppMenu.openMenuIndex] ?? null
    readonly property var firstLevel: topItem?.children ?? []
    readonly property var secondLevel: AppMenu.openSubmenuIndex >= 0 ? (firstLevel[AppMenu.openSubmenuIndex]?.children ?? []) : []
    readonly property var thirdLevel: AppMenu.openNestedSubmenuIndex >= 0 ? (secondLevel[AppMenu.openNestedSubmenuIndex]?.children ?? []) : []
    readonly property real inset: Tokens.padding.medium
    readonly property real columnGap: Tokens.spacing.small

    function columnWidth(items: var): real {
        let longest = 0;
        for (let i = 0; i < items.length; ++i)
            longest = Math.max(longest, String(items[i].text || "—").length);
        return Math.max(150, Math.min(280, longest * 7.2 + 58));
    }

    implicitWidth: Math.min(firstColumn.implicitWidth + (secondLevel.length ? columnGap + secondColumn.implicitWidth : 0) + (thirdLevel.length ? columnGap + thirdColumn.implicitWidth : 0) + inset * 2, 700)
    implicitHeight: Math.min(Math.max(firstColumn.implicitHeight, secondColumn.implicitHeight, thirdColumn.implicitHeight) + inset * 2, 620)

    RowLayout {
        anchors.fill: parent
        anchors.margins: root.inset
        spacing: root.columnGap

        ColumnLayout {
            id: firstColumn
            implicitWidth: root.columnWidth(root.firstLevel)
            Layout.preferredWidth: root.columnWidth(root.firstLevel)
            spacing: Tokens.spacing.extraSmall
            Repeater {
                model: root.firstLevel
                delegate: MenuRow {
                    required property int index
                    required property var modelData
                    entry: modelData
                    selected: AppMenu.openSubmenuIndex === index
                    onActivated: item => {
                        if (item.children?.length) {
                            AppMenu.openSubmenuIndex = index;
                            AppMenu.openNestedSubmenuIndex = -1;
                        } else AppMenu.activate(item);
                    }
                }
            }
        }

        ColumnLayout {
            id: secondColumn
            implicitWidth: root.columnWidth(root.secondLevel)
            visible: root.secondLevel.length > 0
            Layout.preferredWidth: visible ? root.columnWidth(root.secondLevel) : 0
            spacing: Tokens.spacing.extraSmall
            Repeater {
                model: root.secondLevel
                delegate: MenuRow {
                    required property int index
                    required property var modelData
                    entry: modelData
                    selected: AppMenu.openNestedSubmenuIndex === index
                    onActivated: item => {
                        if (item.children?.length) AppMenu.openNestedSubmenuIndex = index;
                        else AppMenu.activate(item);
                    }
                }
            }
        }

        ColumnLayout {
            id: thirdColumn
            implicitWidth: root.columnWidth(root.thirdLevel)
            visible: root.thirdLevel.length > 0
            Layout.preferredWidth: visible ? root.columnWidth(root.thirdLevel) : 0
            spacing: Tokens.spacing.extraSmall
            Repeater {
                model: root.thirdLevel
                delegate: MenuRow {
                    required property var modelData
                    entry: modelData
                    onActivated: item => AppMenu.activate(item)
                }
            }
        }
    }

    component MenuRow: Item {
        id: row
        required property var entry
        property bool selected: false
        signal activated(var item)
        readonly property bool pressed: rowMouse.pressed
        Layout.fillWidth: true
        implicitHeight: 34

        StyledRect {
            anchors.fill: parent
            radius: Tokens.rounding.small
            color: row.pressed ? Colours.palette.m3primary : (row.selected ? Colours.palette.m3secondaryContainer : "transparent")
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.medium
            anchors.rightMargin: Tokens.padding.medium
            spacing: Tokens.spacing.small
            StyledText {
                Layout.fillWidth: true
                text: row.entry.text || "—"
                color: row.pressed ? Colours.on(Colours.palette.m3primary) : (row.entry.enabled === false ? Colours.on(Colours.tPalette.m3surfaceVariant) : (row.selected ? Colours.on(Colours.palette.m3secondaryContainer) : Colours.on(Colours.tPalette.m3surface)))
                font: Tokens.font.body.builders.medium.scale(0.96).build()
                elide: Text.ElideRight
            }
            MaterialIcon {
                visible: row.entry.children?.length > 0
                text: "chevron_right"
                color: Colours.on(Colours.tPalette.m3surface)
            }
        }
        MouseArea {
            id: rowMouse
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            enabled: row.entry.enabled !== false
            cursorShape: Qt.PointingHandCursor
            onClicked: row.activated(row.entry)
        }
    }
}
