#!/usr/bin/env python3
"""Collect Arch, AUR, and Flatpak updates as JSON for Noctalia."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from typing import Any

UPDATE_RE = re.compile(r"^(\S+)\s+(\S+)\s+->\s+(\S+)")


def run(command: str, timeout: int = 90) -> tuple[int, str, str]:
    if not command.strip():
        return 0, "", ""
    completed = subprocess.run(
        command,
        shell=True,
        executable="/bin/sh",
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )
    return completed.returncode, completed.stdout, completed.stderr


def parse_arch_output(output: str, source: str) -> list[dict[str, str]]:
    updates = []
    for line in output.splitlines():
        match = UPDATE_RE.match(line.strip())
        if match:
            name, old_version, new_version = match.groups()
            updates.append({
                "id": name,
                "name": name,
                "oldVersion": old_version,
                "newVersion": new_version,
                "source": source,
            })
    return updates


def flatpak_updates() -> tuple[list[dict[str, str]], str | None]:
    code, output, error = run("flatpak remote-ls --updates --columns=application,version 2>/dev/null")
    if code != 0:
        return [], error.strip() or f"flatpak exited with code {code}"
    updates = []
    for line in output.splitlines():
        columns = line.split("\t")
        if not columns or not columns[0].strip():
            continue
        app_id = columns[0].strip()
        version = columns[1].strip() if len(columns) > 1 else "available"
        updates.append({
            "id": app_id,
            "name": app_id,
            "oldVersion": "installed",
            "newVersion": version,
            "source": "flatpak",
        })
    return updates, None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--system-command", default="checkupdates 2>/dev/null")
    parser.add_argument("--aur-command", default="yay -Qua 2>/dev/null")
    parser.add_argument("--flatpak", action="store_true")
    args = parser.parse_args()

    updates: list[dict[str, str]] = []
    warnings: list[str] = []
    for source, command in (("system", args.system_command), ("aur", args.aur_command)):
        code, output, error = run(command)
        # checkupdates/yay use nonzero statuses for "none" in some versions.
        parsed = parse_arch_output(output, source)
        updates.extend(parsed)
        if code not in (0, 1, 2) and not parsed:
            warnings.append(error.strip() or f"{source} check exited with code {code}")

    if args.flatpak:
        flatpak, warning = flatpak_updates()
        updates.extend(flatpak)
        if warning:
            warnings.append(warning)

    updates.sort(key=lambda item: (item["source"], item["name"].lower()))
    result: dict[str, Any] = {
        "ok": not warnings,
        "updates": updates,
        "count": len(updates),
        "noctaliaUpdate": any(item["name"] in {"noctalia", "noctalia-git", "noctalia-qs", "noctalia-shell"} for item in updates),
        "warnings": warnings,
    }
    if warnings:
        result["error"] = "\n".join(warnings)
    print(json.dumps(result, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
