# Caelestia app menu

The optional app menu is enabled from **Settings → Wallpaper & style → Window appearance**. When active, Caelestia reads the focused Hyprland window's accessible menubar through AT-SPI and renders it in the top-left Caelestia frame surface, regardless of the configured bar edge. Menu actions are sent back to the owning application through its AT-SPI action interface. For applications without an accessible menubar, the menu offers the active window's close, minimize, fullscreen, and floating actions.

When an application exposes a checkable **Menubar** visibility action, Caelestia hides its in-window menubar while the feature is enabled and restores the prior visibility when disabled. Mousepad uses its GSettings menubar preference for this. Applications without a visibility switch keep their in-window menubar.

The implementation follows the data flow used by [noctalia-appmenu](https://github.com/yolo-labz/noctalia-appmenu), but uses Hyprland's active-window state and keeps the menu in Caelestia's existing bar/panel surface. The upstream bridge is Niri-specific, so its focus daemon and Niri fallback actions are not used.

Qt applications need accessibility enabled before launch. Enabling the setting exports `QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1` to subsequently launched Hyprland applications; restart Qt applications that were already open. The helper uses Ubuntu's `python3-pyatspi` package to read and activate accessible menu items.
