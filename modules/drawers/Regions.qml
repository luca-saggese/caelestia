pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.modules.bar as Bar

Region {
    id: root

    required property Bar.BarWrapper bar
    required property Panels panels
    required property var win
    required property Item menuStrip

    x: 0
    y: 0
    width: win.width
    height: win.height
    intersection: Intersection.Combine

    // Start with the full screen as the input surface, then remove its central
    // area. This leaves the frame and bar interactive while clicks pass through
    // to applications everywhere else.
    Region {
        x: root.bar.clampedInsetLeft + root.win.dragMaskPadding
        y: root.bar.clampedInsetTop + root.win.dragMaskPadding
        width: root.win.width - root.bar.clampedInsetLeft - root.bar.clampedInsetRight - root.win.dragMaskPadding * 2
        height: root.win.height - root.bar.clampedInsetTop - root.bar.clampedInsetBottom - root.win.dragMaskPadding * 2
        intersection: Intersection.Xor
    }

    R {
        panel: root.panels.dashboard
        y: root.panels.dashboard.atTop ? 0 : root.win.height - height
        height: panel.height * (1 - root.panels.dashboard.offsetScale) + (root.panels.dashboard.atTop ? root.bar.insetTop : root.bar.insetBottom)
    }

    R {
        panel: root.panels.launcher
        y: root.panels.launcher.atTop ? 0 : root.win.height - height
        height: panel.height * (1 - root.panels.launcher.offsetScale) + (root.panels.launcher.atTop ? root.bar.insetTop : root.bar.insetBottom)
    }

    R {
        id: sessionRegion

        panel: root.panels.sessionWrapper
        x: root.panels.sessionLeft ? 0 : root.win.width - width
        width: panel.width * (1 - root.panels.session.offsetScale) + (root.panels.sessionLeft ? root.bar.insetLeft : root.bar.insetRight) + (root.panels.sessionWithStack ? sidebarRegion.width : 0)
    }

    R {
        id: sidebarRegion

        panel: root.panels.sidebar
        x: root.panels.stackLeft ? 0 : root.win.width - width
        width: panel.width * (1 - root.panels.sidebar.offsetScale) + (root.panels.stackLeft ? root.bar.insetLeft : root.bar.insetRight)
    }

    R {
        panel: root.panels.osdWrapper
        x: root.panels.osdLeft ? 0 : root.win.width - width
        width: panel.width * (1 - root.panels.osd.offsetScale) + (root.panels.osdLeft ? root.bar.insetLeft : root.bar.insetRight) + (root.panels.osdWithSession ? sessionRegion.width : root.panels.osdWithStack ? sidebarRegion.width : 0)
    }

    R {
        panel: root.panels.notifications
        y: 0
        height: panel.height + root.bar.insetTop
    }

    R {
        panel: root.panels.utilities
        y: root.win.height - height
        height: panel.height * (1 - root.panels.utilities.offsetScale) + root.bar.insetBottom
    }

    // While a popout is open its input area is its final one, not the one it is animating through, so the pointer
    // can move onto it as soon as it starts to appear
    Region {
        readonly property Item p: root.panels.popoutsWrapper
        readonly property bool open: root.panels.popouts.hasCurrent || root.panels.popouts.isDetached

        x: root.bar.insetLeft + (open ? p.targetX : p.x)
        y: root.bar.insetTop + (open ? p.targetY : p.y)
        width: open ? p.targetW : (root.bar.vertical ? p.width * (1 - p.offsetScale) : p.width)
        height: open ? p.targetH : (root.bar.vertical ? p.height : p.height * (1 - p.offsetScale))
        intersection: Intersection.Subtract
    }

    // Re-add the app-menu hit target last: the notification and other panel
    // exclusions above overlap the top frame where its buttons are drawn.
    Region {
        x: root.menuStrip.x
        y: root.menuStrip.y
        width: root.menuStrip.visible ? root.menuStrip.width : 0
        height: root.menuStrip.visible ? root.menuStrip.height : 0
        intersection: Intersection.Combine
    }

    component R: Region {
        required property Item panel

        x: panel.x + root.bar.insetLeft
        y: panel.y + root.bar.insetTop
        width: panel.width
        height: panel.height
        intersection: Intersection.Subtract
    }
}
