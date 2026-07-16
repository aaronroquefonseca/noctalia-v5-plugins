#!/usr/bin/env python3
"""Run bounded fd searches and return launcher-ready JSON."""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import shlex
import subprocess
from typing import Any


def output(payload: dict[str, Any]) -> int:
    print(json.dumps(payload, separators=(",", ":"), ensure_ascii=False))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--query", required=True)
    parser.add_argument("--roots-json", required=True)
    parser.add_argument("--limit", type=int, default=80)
    parser.add_argument("--fd-command", default="fd")
    parser.add_argument("--hidden", action="store_true")
    args = parser.parse_args()

    try:
        configured_roots = json.loads(args.roots_json)
    except json.JSONDecodeError as error:
        return output({"ok": False, "error": f"Invalid search roots: {error}"})
    if not isinstance(configured_roots, list):
        return output({"ok": False, "error": "Search roots must be a list"})

    roots = [os.path.abspath(os.path.expanduser(str(root))) for root in configured_roots]
    roots = [root for root in roots if os.path.isdir(root)]
    if not roots:
        return output({"ok": False, "error": "No configured search root exists"})

    fd_parts = shlex.split(args.fd_command)
    if not fd_parts:
        return output({"ok": False, "error": "fd command is empty"})
    limit = max(10, min(500, args.limit))
    command = fd_parts + [
        "--absolute-path",
        "--color", "never",
        "--fixed-strings",
        "--ignore-case",
        "--max-results", str(limit),
    ]
    if args.hidden:
        command.append("--hidden")
    command += ["--", args.query, *roots]

    try:
        completed = subprocess.run(command, capture_output=True, text=True, timeout=12, check=False)
    except (OSError, subprocess.TimeoutExpired) as error:
        return output({"ok": False, "error": str(error)})
    if completed.returncode != 0:
        return output({"ok": False, "error": completed.stderr.strip() or f"fd exited with code {completed.returncode}"})

    results = []
    seen: set[str] = set()
    for raw_path in completed.stdout.splitlines():
        path = os.path.normpath(raw_path)
        if not path or path in seen:
            continue
        seen.add(path)
        item = pathlib.Path(path)
        results.append({
            "path": path,
            "name": item.name or path,
            "parent": str(item.parent),
            "directory": item.is_dir(),
        })
    results.sort(key=lambda item: (not item["directory"], item["name"].casefold(), item["path"].casefold()))
    return output({"ok": True, "results": results[:limit]})


if __name__ == "__main__":
    raise SystemExit(main())
