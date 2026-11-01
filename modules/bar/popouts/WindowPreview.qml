pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.services

Item {
    id: root

    required property var client

    implicitWidth: 320
    implicitHeight: 224

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: Icons.getAppCategoryIcon(root.client?.lastIpcObject?.class ?? "", "terminal")
                color: Colours.palette.m3primary
            }

            StyledText {
                Layout.fillWidth: true
                text: root.client ? (root.client.title || root.client.lastIpcObject?.class || Tr.tr("Window")) : Tr.tr("Window")
                color: Colours.palette.m3onSurface
                elide: Text.ElideRight
            }
        }

        ClipRect {
            id: previewFrame

            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Colours.palette.m3surfaceContainerHighest
            radius: Tokens.rounding.medium

            ScreencopyView {
                id: screencopy

                anchors.fill: parent
                anchors.margins: Tokens.padding.extraSmall
                captureSource: root.client?.wayland ?? null
                live: root.client !== null
                constraintSize: Qt.size(280, 170)
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
