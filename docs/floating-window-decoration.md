# Floating windows with native Hyprland decoration

The switch is on the main Settings → Wallpaper & style page. Its state is stored in `~/.config/caelestia/window-decor.json` and defaults to off. Enabling it keeps `dwindle` as the underlying layout, floats mapped application windows, enables edge resizing, and activates the Hyprland `hyprbars` decoration. Quickshell surfaces, fullscreen clients, and windows in `special:minimized` are excluded. Disabling the switch tiles the clients the feature managed.

On each `openwindow` event, refresh the Quickshell Hyprland toplevel cache before reading `lastIpcObject`, then defer the float pass briefly so the new client's mapped/workspace state is available. This ensures the first client opened after enabling the feature gets floated as well. A one-second reconciliation timer remains as a fallback for state changes that do not produce an `openwindow` event.

While enabled, `general.border_size=0` removes the compositor outline around the client content; disabling the feature restores the configured 2 px border. The title bar stays a native decoration with `bar_part_of_window=false`. Active and inactive borders use Caelestia's current Material 3 primary color to prevent hover focus from changing their color; the title bar background and text use `surfaceContainerHigh` and `onSurface`.

Floating clients are kept within the monitor's usable area below its reserved top bar, with a 24 px margin. The controller uses monitor reservation data from Hyprland IPC and clamps both size and position.

The `hyprbars` plugin must be installed and loaded by the Hyprland session before this service starts. On the Ubuntu VM it is supplied by `caelestia-hyprbars` and loaded from `/etc/caelestia-sessions/caelestia.lua`. The fork's `install.sh` targets Arch Linux; Ubuntu installation uses the CMake build with `CMAKE_INSTALL_PREFIX=/` and `INSTALL_QSCONFDIR=etc/xdg/quickshell/caelestia`.
