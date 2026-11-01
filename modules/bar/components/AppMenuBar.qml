import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// The application menu strip is part of the bar; its contents use the shared
// popout system (and therefore the same BlobGroup surface as every Caelestia panel).
Item {
    id: root

    required property var popouts
    required property Item bar
    readonly property var entries: AppMenu.entries
    implicitWidth: row.implicitWidth
    implicitHeight: Tokens.sizes.bar.innerWidth - Tokens.padding.small
    width: implicitWidth
    height: implicitHeight
    visible: WindowDecorSettings.appMenuEnabled && entries.length > 0
    z: 1001

    function selectMenu(index: int): void {
        console.info("appmenu-test select", index, entries.length, popouts.currentName, popouts.hasCurrent);
        if (index < 0 || index >= entries.length)
            return;
        if (entries[index].enabled === false)
            return;
        const entry = entries[index];
        if (entry.children?.length === 0) {
            AppMenu.activate(entry);
            return;
        }
        if (AppMenu.openMenuIndex === index && popouts.currentName === "appmenu" && popouts.hasCurrent) {
            AppMenu.closeMenus();
            popouts.hasCurrent = false;
            return;
        }
        AppMenu.openMenuIndex = index;
        AppMenu.openSubmenuIndex = -1;
        AppMenu.openNestedSubmenuIndex = -1;
        const item = menuRepeater.itemAt(index);
        if (!item) {
            console.warn("Caelestia app menu: clicked entry has no delegate", index);
            return;
        }
        const center = item.mapToItem(bar, item.width / 2, item.height / 2);
        // The application menu is laid out on the top frame even when the
        // regular workspace bar is vertical.
        popouts.currentCenter = center.x;
        popouts.currentName = "appmenu";
        popouts.hasCurrent = true;
        console.info("appmenu-test opened", index, popouts.currentName, popouts.hasCurrent, center.x);
    }

    Row {
        id: row
        height: root.height
        spacing: Tokens.spacing.extraSmall

        Repeater {
            id: menuRepeater
            model: root.entries
            delegate: Item {
                id: topItem
                required property int index
                required property var modelData
                implicitWidth: label.implicitWidth + Tokens.padding.medium * 2
                implicitHeight: root.height

                TextButton {
                    id: label
                    anchors.fill: parent
                    text: topItem.modelData.text
                    type: TextButton.Text
                    isToggle: true
                    checked: AppMenu.openMenuIndex === topItem.index && root.popouts.currentName === "appmenu" && root.popouts.hasCurrent
                    horizontalPadding: Tokens.padding.medium
                    verticalPadding: 0
                    radiusMorph: false
                    pressedRadius: 0
                    checkedRadius: 0
                    defaultRadius: 0
                    font: Tokens.font.label.builders.large.scale(0.96).build()
                    onClicked: {
                        console.info("appmenu-test button clicked", topItem.index);
                        root.selectMenu(topItem.index);
                    }
                }
            }
        }
    }

    Connections {
        target: root.popouts
        function onHasCurrentChanged(): void {
            if (!root.popouts.hasCurrent && root.popouts.currentName === "appmenu")
                AppMenu.closeMenus();
        }
        function onCurrentNameChanged(): void {
            if (root.popouts.currentName !== "appmenu")
                AppMenu.closeMenus();
        }
    }
}
