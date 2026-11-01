#!/usr/bin/python3
"""Expose the focused Hyprland application's accessible menu to Caelestia.

The QML shell owns presentation and theming. This helper only reads the AT-SPI
tree for the focused PID and forwards leaf-item actions back to that tree.
"""

import json
import subprocess
import sys
from pathlib import Path

import pyatspi


NATIVE_MENU_STATE = Path.home() / ".cache/caelestia/appmenu-native-menus.json"


def active_window():
    try:
        data = subprocess.check_output(
            ["hyprctl", "activewindow", "-j"], text=True, timeout=1.5
        )
        return json.loads(data)
    except Exception:
        return {}


def visible(node):
    try:
        return node.getState().contains(pyatspi.STATE_VISIBLE)
    except Exception:
        return True


def enabled(node):
    try:
        return node.getState().contains(pyatspi.STATE_ENABLED)
    except Exception:
        return True


def children(node, only_visible=True):
    try:
        count = min(int(node.childCount), 250)
    except Exception:
        return []
    result = []
    for index in range(count):
        try:
            child = node.getChildAtIndex(index)
            if child is not None and (not only_visible or visible(child)):
                result.append(child)
        except Exception:
            continue
    return result


def find_menubar(node, depth=0):
    if depth > 10:
        return None
    try:
        if node.getRoleName().lower().replace("_", " ") == "menu bar":
            return node
    except Exception:
        pass
    # AT-SPI application roots often report STATE_VISIBLE=false even while
    # their active frame and menubar are visible. Traverse container nodes
    # regardless of that state, then filter the actual menu entries later.
    for child in children(node, only_visible=False):
        found = find_menubar(child, depth + 1)
        if found is not None:
            return found
    return None


def encode_item(node, depth=0):
    if depth > 8:
        return None
    try:
        label = (node.name or "").strip()
        path = str(node.path)
        role = node.getRoleName().lower()
    except Exception:
        return None
    nested = menu_children(node)
    encoded_children = []
    for child in nested:
        item = encode_item(child, depth + 1)
        if item is not None:
            encoded_children.append(item)
    if not label and not encoded_children:
        return None
    return {
        "text": label,
        "path": path,
        "role": role,
        "enabled": enabled(node),
        "children": encoded_children,
    }


def menu_children(node):
    """Flatten Qt's hidden popup-menu wrapper but keep every menu item."""
    result = []
    for child in children(node, only_visible=False):
        try:
            role = child.getRoleName().lower()
        except Exception:
            role = ""
        if role in ("popup menu", "menu"):
            result.extend(children(child, only_visible=False))
        else:
            result.append(child)
    return result


def locate_app(pid):
    desktop = pyatspi.Registry.getDesktop(0)
    # Application accessibles are commonly not marked visible even when their
    # process has a visible, focused frame.
    for app in children(desktop, only_visible=False):
        try:
            if int(app.get_process_id()) == pid:
                return app
        except Exception:
            continue
    return None


def snapshot():
    active = active_window()
    pid = int(active.get("pid") or 0)
    app = locate_app(pid) if pid else None
    result = {
        "pid": pid,
        "class": str(active.get("class") or active.get("initialClass") or ""),
        "title": str(active.get("title") or active.get("class") or ""),
        "entries": [],
    }
    menubar = None
    try:
        if app is not None:
            result["title"] = app.name or result["title"]
            menubar = find_menubar(app)
        if menubar is not None:
            result["entries"] = [entry for child in children(menubar) if (entry := encode_item(child)) is not None]
    except Exception:
        pass
    app_class = str(active.get("class") or active.get("initialClass") or "").lower()
    if app_class in {"quickshell", "org.quickshell", "qs"}:
        return result
    if not result["entries"] and pid > 0 and active.get("address"):
        address = f'address:{active["address"]}'

        def action(text, command):
            return {"text": text, "path": "", "role": "menu item", "enabled": True,
                    "children": [], "kind": "hyprland", "action": command, "address": address}

        app_name = str(active.get("class") or active.get("title") or "Application")
        result["entries"] = [
            {"text": app_name, "path": "", "role": "menu item", "enabled": True,
             "children": [action("Quit", "close")], "kind": "hyprland"},
            {"text": "Window", "path": "", "role": "menu item", "enabled": True,
             "children": [
                 action("Close", "close"),
                 action("Minimize", "minimize"),
                 action("Toggle Fullscreen", "fullscreen"),
                 action("Toggle Floating", "floating"),
             ], "kind": "hyprland"},
        ]
    return result


def find_path(node, path, depth=0):
    if depth > 12:
        return None
    try:
        if str(node.path) == path:
            return node
    except Exception:
        return None
    for child in children(node, only_visible=False):
        found = find_path(child, path, depth + 1)
        if found is not None:
            return found
    return None


def walk(node, depth=0):
    if depth > 16:
        return
    yield node
    for child in children(node, only_visible=False):
        yield from walk(child, depth + 1)


def checked(node):
    try:
        return node.getState().contains(pyatspi.STATE_CHECKED)
    except Exception:
        return False


def save_native_menu_states(states):
    NATIVE_MENU_STATE.parent.mkdir(parents=True, exist_ok=True)
    if states:
        NATIVE_MENU_STATE.write_text(json.dumps(states), encoding="utf-8")
    else:
        NATIVE_MENU_STATE.unlink(missing_ok=True)


def set_native_menus(hide, pid=0):
    try:
        states = json.loads(NATIVE_MENU_STATE.read_text(encoding="utf-8"))
    except Exception:
        states = []

    if hide:
        if not pid or any(int(item.get("pid", 0)) == pid for item in states):
            return 0
        app = locate_app(pid)
        if app is None:
            return 2
        # Mousepad exposes a live GSettings preference; using it is more
        # reliable than the checked state of its hidden View-menu checkbox.
        if app.name == "org.xfce.mousepad":
            schema = "org.xfce.mousepad.preferences.window"
            key = "menubar-visible"
            if not any(item.get("kind") == "gsettings" for item in states):
                try:
                    original = subprocess.check_output(["gsettings", "get", schema, key], text=True, timeout=2).strip() == "true"
                    states.append({"kind": "gsettings", "schema": schema, "key": key, "value": original})
                    save_native_menu_states(states)
                except Exception:
                    return 6
            try:
                subprocess.run(["gsettings", "set", schema, key, "false"], check=True, timeout=2)
                return 0
            except Exception:
                return 6
        for node in walk(app):
            try:
                name = (node.name or "").strip().lower().replace("_", " ")
                if name not in {"menubar", "menu bar", "show menubar", "show menu bar"}:
                    continue
                if not checked(node):
                    continue
                actions = node.queryAction()
                if actions.nActions < 1 or not actions.doAction(0):
                    return 4
                states.append({"pid": pid, "path": str(node.path), "checked": True})
                save_native_menu_states(states)
                return 0
            except Exception:
                continue
        return 5

    remaining = []
    result = 0
    for item in states:
        if item.get("kind") == "gsettings":
            try:
                subprocess.run(["gsettings", "set", item["schema"], item["key"], "true" if item.get("value") else "false"], check=True, timeout=2)
            except Exception:
                remaining.append(item)
                result = 6
            continue
        app = locate_app(int(item.get("pid", 0)))
        if app is None:
            continue
        node = find_path(app, item.get("path", ""))
        if node is None:
            remaining.append(item)
            result = 5
            continue
        desired = bool(item.get("checked", False))
        if checked(node) != desired:
            try:
                actions = node.queryAction()
                if actions.nActions < 1 or not actions.doAction(0):
                    remaining.append(item)
                    result = 4
            except Exception:
                remaining.append(item)
                result = 4
    save_native_menu_states(remaining)
    return result


def click(pid, path):
    app = locate_app(int(pid))
    if app is None:
        return 2
    node = find_path(app, path)
    if node is None:
        return 3
    try:
        actions = node.queryAction()
        return 0 if actions.nActions > 0 and actions.doAction(0) else 4
    except Exception:
        return 4


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "native-menu":
        if len(sys.argv) == 4 and sys.argv[2] == "hide":
            sys.exit(set_native_menus(True, int(sys.argv[3])))
        if len(sys.argv) == 3 and sys.argv[2] == "restore":
            sys.exit(set_native_menus(False))
        sys.exit(64)
    if len(sys.argv) >= 2 and sys.argv[1] == "click" and len(sys.argv) == 4:
        sys.exit(click(sys.argv[2], sys.argv[3]))
    print(json.dumps(snapshot(), separators=(",", ":")))
