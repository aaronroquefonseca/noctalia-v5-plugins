#!/usr/bin/env python3
"""Enumerate and safely operate on removable USB filesystems."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import time
from typing import Any

LSBLK_COLUMNS = "NAME,PATH,TYPE,TRAN,RM,HOTPLUG,LABEL,FSTYPE,SIZE,MOUNTPOINTS,MODEL,VENDOR"


def emit(payload: dict[str, Any]) -> int:
    print(json.dumps(payload, separators=(",", ":"), ensure_ascii=False))
    return 0


def lsblk() -> list[dict[str, Any]]:
    completed = subprocess.run(
        ["lsblk", "-J", "-o", LSBLK_COLUMNS],
        capture_output=True,
        text=True,
        timeout=8,
        check=True,
    )
    return json.loads(completed.stdout).get("blockdevices", [])


def mounted_path(device: dict[str, Any]) -> str:
    for mountpoint in device.get("mountpoints") or []:
        if mountpoint and mountpoint != "[SWAP]":
            return str(mountpoint)
    return ""


def inventory() -> tuple[list[dict[str, Any]], dict[str, dict[str, Any]], dict[str, dict[str, Any]]]:
    results: list[dict[str, Any]] = []
    filesystems: dict[str, dict[str, Any]] = {}
    disks: dict[str, dict[str, Any]] = {}

    def walk(device: dict[str, Any], parent: dict[str, Any] | None, removable: bool) -> None:
        current_removable = removable or device.get("tran") == "usb" or bool(device.get("rm")) or bool(device.get("hotplug"))
        path = str(device.get("path") or "")
        if current_removable and device.get("type") == "disk" and path:
            disks[path] = device
        children = device.get("children") or []
        for child in children:
            walk(child, device if device.get("type") == "disk" else parent, current_removable)
        if not current_removable or not device.get("fstype") or not path:
            return
        parent_path = str((parent or device).get("path") or path)
        mountpoint = mounted_path(device)
        usage = None
        if mountpoint:
            try:
                usage = shutil.disk_usage(mountpoint)
            except OSError:
                usage = None
        item = {
            "name": str(device.get("name") or os.path.basename(path)),
            "path": path,
            "parentPath": parent_path,
            "label": str(device.get("label") or ""),
            "model": str((parent or device).get("model") or "").strip(),
            "vendor": str((parent or device).get("vendor") or "").strip(),
            "fstype": str(device.get("fstype") or ""),
            "size": str(device.get("size") or ""),
            "mountpoint": mountpoint,
            "mounted": bool(mountpoint),
            "usedPercent": round((usage.used / usage.total) * 100) if usage and usage.total else 0,
            "freeBytes": usage.free if usage else None,
        }
        results.append(item)
        filesystems[path] = item

    for root in lsblk():
        walk(root, None, False)
    results.sort(key=lambda item: (item["parentPath"], item["path"]))
    return results, filesystems, disks


def run_udisks(arguments: list[str]) -> tuple[bool, str]:
    completed = subprocess.run(["udisksctl", *arguments], capture_output=True, text=True, timeout=90, check=False)
    message = (completed.stdout or completed.stderr).strip()
    return completed.returncode == 0, message


def perform(action: str, path: str) -> dict[str, Any]:
    devices, filesystems, disks = inventory()
    del devices
    if action in {"mount", "unmount"}:
        device = filesystems.get(path)
        if not device:
            return {"ok": False, "error": "Refusing action: device is not a current removable USB filesystem"}
        verb = "mount" if action == "mount" else "unmount"
        ok, message = run_udisks([verb, "-b", path])
        return {"ok": ok, "message" if ok else "error": message or f"Could not {verb} {path}"}
    if action == "eject":
        device = filesystems.get(path)
        if not device:
            return {"ok": False, "error": "Refusing eject: device is not a current removable USB filesystem"}
        parent = device["parentPath"]
        if parent not in disks:
            return {"ok": False, "error": "Refusing eject: removable parent disk was not found"}
        for filesystem in filesystems.values():
            if filesystem["parentPath"] == parent and filesystem["mounted"]:
                ok, message = run_udisks(["unmount", "-b", filesystem["path"]])
                if not ok:
                    return {"ok": False, "error": message or f"Could not unmount {filesystem['path']}"}
        ok, message = run_udisks(["power-off", "-b", parent])
        if not ok and not message:
            # Some USB-SATA bridges complete power-off but drop the device
            # before udisksctl can return a successful D-Bus response.
            return {"ok": True, "message": f"Safely powered off {parent}"}
        if not ok:
            # Some USB bridges disappear before UDisks returns its D-Bus reply.
            # The physical power-off succeeded, but udisksctl reports failure.
            for _ in range(20):
                time.sleep(0.25)
                _, remaining_filesystems, remaining_disks = inventory()
                if path not in remaining_filesystems or parent not in remaining_disks:
                    return {"ok": True, "message": f"Safely powered off {parent}"}
            return {"ok": True, "message": f"Safely unmounted; power-off requested for {parent}"}
        return {"ok": True, "message": message or f"Safely powered off {parent}"}
    return {"ok": False, "error": f"Unsupported action: {action}"}


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("list")
    action_parser = subparsers.add_parser("action")
    action_parser.add_argument("--action", choices=("mount", "unmount", "eject"), required=True)
    action_parser.add_argument("--path", required=True)
    args = parser.parse_args()
    try:
        if args.command == "list":
            devices, _, _ = inventory()
            return emit({"ok": True, "devices": devices, "count": len(devices)})
        return emit(perform(args.action, args.path))
    except (OSError, subprocess.SubprocessError, json.JSONDecodeError) as error:
        return emit({"ok": False, "error": str(error)})


if __name__ == "__main__":
    raise SystemExit(main())
