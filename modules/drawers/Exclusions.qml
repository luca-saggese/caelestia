pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components.containers
import qs.modules.bar as Bar

Scope {
    id: root

    required property ShellScreen screen
    required property Bar.BarWrapper bar

    // The bar's zone replaces the plain border zone on whichever edge it is attached to
    ExclusionZone {
        anchors.left: true
        exclusiveZone: root.bar.onLeft ? root.bar.exclusiveZone : root.bar.borderInsetLeft
    }

    ExclusionZone {
        anchors.top: true
        exclusiveZone: root.bar.onTop ? root.bar.exclusiveZone : root.bar.borderInsetTop
    }

    ExclusionZone {
        anchors.right: true
        exclusiveZone: root.bar.onRight ? root.bar.exclusiveZone : root.bar.borderInsetRight
    }

    ExclusionZone {
        anchors.bottom: true
        exclusiveZone: root.bar.onBottom ? root.bar.exclusiveZone : root.bar.borderInsetBottom
    }

    component ExclusionZone: StyledWindow {
        screen: root.screen
        name: "border-exclusion"
        exclusiveZone: root.bar.borderAtBarEdge
        mask: Region {}
        implicitWidth: 1
        implicitHeight: 1
    }
}
