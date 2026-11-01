pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.services

// Controls native Hyprland floating windows and the hyprbars decoration.
Singleton {
    id: root

    readonly property bool enabled: WindowDecorSettings.enabled
    readonly property list<string> excludedClasses: ["org.quickshell", "quickshell"]
    property bool initialized: false

    Timer {
        interval: 250
        repeat: true
        running: root.enabled
        onTriggered: root.refreshWindows()
    }

    Connections {
        target: WindowDecorSettings
        function onLoadedChanged(): void {
            if (WindowDecorSettings.loaded)
                root.initializeMode();
        }
        function onEnabledChanged(): void {
            if (WindowDecorSettings.loaded)
                root.applyMode();
        }
    }

    Connections {
        target: Colours.palette
        function onM3primaryChanged(): void { if (root.enabled) root.applySettings(); }
        function onM3surfaceContainerHighChanged(): void { if (root.enabled) root.applySettings(); }
        function onM3onSurfaceChanged(): void { if (root.enabled) root.applySettings(); }
    }

    Component.onCompleted: {
        root.addButtonsOnce();
        if (WindowDecorSettings.loaded)
            root.initializeMode();
    }

    function dispatchLua(body: string): void {
        Hyprland.dispatch(`function() ${body} end`);
    }

    function dispatchAction(body: string): void {
        // Hyprland Lua dispatchers must be sent directly; returning one from a
        // callback does not execute the window action.
        Hyprland.dispatch(body);
    }

    function hyprColor(value: color): string {
        function byteHex(channel: real): string {
            const hex = Math.max(0, Math.min(255, Math.round(channel * 255))).toString(16);
            return hex.length === 1 ? `0${hex}` : hex;
        }
        return `rgba(${byteHex(value.r)}${byteHex(value.g)}${byteHex(value.b)}${byteHex(value.a)})`;
    }

    function applySettings(): void {
        const active = root.enabled ? "true" : "false";
        const borderSize = root.enabled ? 0 : 2;
        const primary = root.hyprColor(Colours.palette.m3primary);
        const borderColors = root.enabled
            ? `col={active_border="${primary}",inactive_border="${primary}"}`
            : 'col={active_border={colors={"rgba(33ccffee)","rgba(00ff99ee)"},angle=45},inactive_border="rgba(595959aa)"}';

        root.dispatchLua(`hl.config({general={layout="dwindle",border_size=${borderSize},resize_on_border=${active},${borderColors}},plugin={hyprbars={enabled=${active},bar_height=28,bar_color="${root.hyprColor(Colours.palette.m3surfaceContainerHigh)}",col={text="${root.hyprColor(Colours.palette.m3onSurface)}"},bar_text_font="Noto Sans",bar_text_size=13,bar_text_weight=600,bar_text_align="center",bar_buttons_alignment="left",bar_padding=13,bar_button_padding=8,icon_on_hover=true,buttons_on_hover=false,bar_part_of_window=false}}})`);
    }

    function addButtonsOnce(): void {
        root.dispatchLua("if not _G.caelestiaHyprbarsButtonsInstalled then " +
            "hl.plugin.hyprbars.add_button({bg_color='rgb(ff5f57)',fg_color='rgb(801010)',size=12,icon='×',action=[[hyprctl dispatch 'hl.dsp.window.close()']]}); " +
            "hl.plugin.hyprbars.add_button({bg_color='rgb(febc2e)',fg_color='rgb(604000)',size=12,icon='−',action=[[hyprctl dispatch 'hl.dsp.window.move({ workspace = \"special:minimized\", follow = false })']]}); " +
            "hl.plugin.hyprbars.add_button({bg_color='rgb(28c840)',fg_color='rgb(0a5015)',size=12,icon='↗',action=[[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"toggle\" })']]}); " +
            "_G.caelestiaHyprbarsButtonsInstalled = true end");
    }

    function initializeMode(): void {
        if (root.initialized)
            return;
        root.initialized = true;
        root.applyMode();
    }

    function applyMode(): void {
        root.applySettings();
        if (root.enabled)
            root.refreshWindows();
        else
            root.restoreTiledWindows();
    }

    function refreshWindows(): void {
        if (!root.enabled)
            return;

        const clients = Hypr.toplevels.values.map(t => t.lastIpcObject);
        for (const client of clients) {
            if (!client.mapped || client.hidden || !client.workspace || client.fullscreen === true || client.fullscreen === 2)
                continue;
            if (String(client.workspace.name || "") === "special:minimized")
                continue;
            if (root.excludedClasses.includes(String(client["class"] || "")) || root.excludedClasses.includes(String(client.initialClass || "")))
                continue;

            const address = `0x${String(client.address).replace(/^0x/, "")}`;
            if (!client.floating) {
                WindowDecorSettings.rememberFloating(address);
                root.dispatchAction(`hl.dsp.window.float({action="enable",window="address:${address}"})`);
            } else {
                root.constrainToWorkArea(client, address);
            }
        }
    }

    function constrainToWorkArea(client: var, address: string): void {
        const monitor = Hypr.monitors.values.map(m => m.lastIpcObject).find(m => Number(m.id) === Number(client.monitor));
        if (!monitor)
            return;

        const reserved = monitor.reserved || [0, 0, 0, 0];
        const margin = 24;
        const left = Number(reserved[3] || 0) + margin;
        const top = Number(reserved[0] || 0) + margin;
        const right = Number(reserved[1] || 0) + margin;
        const bottom = Number(reserved[2] || 0) + margin;
        const width = Math.min(Number(client.size[0]), Math.max(320, Number(monitor.width) - left - right));
        const height = Math.min(Number(client.size[1]), Math.max(240, Number(monitor.height) - top - bottom));
        const x = Number(client.at[0]);
        const y = Number(client.at[1]);
        const targetX = Math.max(Number(monitor.x) + left, Math.min(x, Number(monitor.x) + Number(monitor.width) - right - width));
        const targetY = Math.max(Number(monitor.y) + top, Math.min(y, Number(monitor.y) + Number(monitor.height) - bottom - height));

        if (width !== Number(client.size[0]) || height !== Number(client.size[1]))
            root.dispatchAction(`hl.dsp.window.resize({x=${width},y=${height},window="address:${address}"})`);
        if (targetX !== x || targetY !== y)
            root.dispatchAction(`hl.dsp.window.move({x=${targetX},y=${targetY},window="address:${address}"})`);
    }

    function restoreTiledWindows(): void {
        const managed = [...WindowDecorSettings.managedFloating];
        for (const address of managed)
            root.dispatchAction(`hl.dsp.window.float({action="disable",window="address:${address}"})`);
        WindowDecorSettings.clearManagedFloating();
    }
}
