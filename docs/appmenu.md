# Caelestia app menu

The optional app menu is enabled from **Settings → Wallpaper & style → Window appearance**. When active, Caelestia reads the focused Hyprland window's accessible menubar through AT-SPI and renders it in the top-left Caelestia frame surface, regardless of the configured bar edge. Menu actions are sent back to the owning application through its AT-SPI action interface. For applications without an accessible menubar, the menu offers the active window's close, minimize, fullscreen, and floating actions.

When an application exposes a checkable **Menubar** visibility action, Caelestia hides its in-window menubar while the feature is enabled and restores the prior visibility when disabled. Mousepad uses its GSettings menubar preference for this. Applications without a visibility switch keep their in-window menubar.

The implementation follows the data flow used by [noctalia-appmenu](https://github.com/yolo-labz/noctalia-appmenu), but uses Hyprland's active-window state and keeps the menu in Caelestia's existing bar/panel surface. The upstream bridge is Niri-specific, so its focus daemon and Niri fallback actions are not used.

The app-menu strip is hidden while the dashboard is open, since the dashboard contains the media player and occupies the same top-edge area. If an app-menu popout was open, opening the dashboard closes it; the strip becomes visible again when the dashboard closes.

## Reusing the border-integrated interaction pattern

Use the existing bar/panel composition instead of creating a separate popup window. The app menu's top-level labels are `TextButton`s in `modules/bar/components/AppMenuBar.qml`; selecting one updates `AppMenu.openMenuIndex`, sets `popouts.currentName` and `popouts.hasCurrent`, and calculates `currentCenter` from the selected delegate. That center anchors the shared popout under the selected label.

The dropdown is registered as a named `Popout` in `modules/bar/popouts/Content.qml`, with its rows rendered by `modules/bar/popouts/ApplicationMenu.qml`. This gives it the same `Popouts.ClipWrapper` placement, `PanelBg`, and `BlobGroup` surface as other Caelestia panels. The menu must remain inside this shared surface: a separate `PopupWindow` or overlay would break the continuous border and its animation/shape integration.

For a new border-integrated panel, follow these steps:

1. Add its surface as a `BlobRect` or `PanelBg` in the existing `blobGroup` in `modules/drawers/ContentWindow.qml`. Keep the visible surface and the interactive item in the same geometry so the pointer never has to cross a gap.
2. Register the content as a named `Popout` in `modules/bar/popouts/Content.qml`. Set the trigger's `currentCenter` and popout state together when opening it; clear `hasCurrent` when closing it.
3. Put real QML controls (`TextButton`, `MouseArea`, or the panel's existing control component) over the visible rows. Let those controls receive clicks; avoid testing raw coordinates in a global handler.
4. Add its clickable shape to `modules/drawers/Regions.qml`. The full-screen frame starts as the input region, the central desktop and panel areas are subtracted, then the app-menu strip is combined back at the end because it overlaps another exclusion. A popout's animated input region should use its final target geometry while opening.
5. Handle dismissal separately from hover. `HyprlandFocusGrab` in `modules/drawers/ContentWindow.qml` watches clicks outside the shell window and clears the popout. `modules/drawers/Interactions.qml` must not clear `appmenu` in `onContainsMouseChanged` or `onPositionChanged`: moving the pointer away leaves it open; clicking outside closes it. This preserves the click-out behavior on both wallpaper and another client.
6. Verify the whole path in the running compositor: open a top-level label, click rows and nested rows, move the pointer away without clicking and confirm the menu stays open, then click wallpaper and another window and confirm each click dismisses it. Wait for the close animation and check that no detached surface or temporary blob remains.

The key state transition is `closed → selected label → shared popout → outside click → closed`. Hover is only a position/visual signal; it is not the dismissal event. The screen-sized `ContentWindow` remains the owner of the frame shape, while the shared popout owns its content and controls.

Qt applications need accessibility enabled before launch. Enabling the setting exports `QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1` to subsequently launched Hyprland applications; restart Qt applications that were already open. The helper uses Ubuntu's `python3-pyatspi` package to read and activate accessible menu items.
