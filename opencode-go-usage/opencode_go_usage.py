#!/usr/bin/env python3
"""Read OpenCode Go quota from the account usage endpoint."""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime
from pathlib import Path
from typing import Any

USAGE_URL = "https://opencode.ai/zen/go/v1/usage"
TIMEOUT_SECONDS = 15


def auth_paths() -> list[Path]:
    paths: list[Path] = []
    xdg_data = os.environ.get("XDG_DATA_HOME")
    if xdg_data:
        paths.append(Path(xdg_data) / "opencode" / "auth.json")
    paths.append(Path.home() / ".local" / "share" / "opencode" / "auth.json")
    paths.append(Path.home() / ".config" / "opencode" / "auth.json")

    unique: list[Path] = []
    seen: set[str] = set()
    for path in paths:
        key = str(path)
        if key not in seen:
            seen.add(key)
            unique.append(path)
    return unique


def key_from_record(record: Any) -> str | None:
    if not isinstance(record, dict):
        return None
    if record.get("type") != "api":
        return None
    key = record.get("key")
    if isinstance(key, str) and key.strip():
        return key.strip()
    return None


def find_api_key() -> tuple[str, str]:
    env_key = os.environ.get("OPENCODE_API_KEY", "").strip()
    if env_key:
        return env_key, "OPENCODE_API_KEY"

    checked: list[str] = []
    for path in auth_paths():
        checked.append(str(path))
        if not path.is_file():
            continue
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        if not isinstance(payload, dict):
            continue

        for provider in ("opencode-go", "opencode"):
            key = key_from_record(payload.get(provider))
            if key:
                return key, f"{path} ({provider})"

    raise FileNotFoundError(
        "OpenCode Go API key not found. Run 'opencode auth login -p opencode-go' "
        "or set OPENCODE_API_KEY."
    )


def parse_reset(value: Any) -> int | None:
    if isinstance(value, (int, float)):
        return int(value)
    if not isinstance(value, str) or not value:
        return None
    text = value.strip()
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        return int(datetime.fromisoformat(text).timestamp())
    except ValueError:
        return None


def normalize_window(raw: Any, duration_minutes: int) -> dict[str, Any]:
    if not isinstance(raw, dict):
        raise ValueError("OpenCode Go usage response is missing a quota window")
    percent = raw.get("percent")
    if not isinstance(percent, (int, float)):
        raise ValueError("OpenCode Go usage response contains an invalid percentage")
    return {
        "usedPercent": max(0.0, min(100.0, float(percent))),
        "resetsAt": parse_reset(raw.get("resetsAt")),
        "status": raw.get("status"),
        "windowDurationMins": duration_minutes,
    }


def fetch_usage(api_key: str) -> dict[str, Any]:
    request = urllib.request.Request(
        USAGE_URL,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Accept": "application/json",
            "User-Agent": "noctalia-opencode-go-usage/0.1.0",
        },
        method="GET",
    )

    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
            payload = json.load(response)
    except urllib.error.HTTPError as exc:
        if exc.code == 401:
            raise RuntimeError("OpenCode Go rejected the API key (HTTP 401)") from exc
        if exc.code == 403:
            raise RuntimeError("This API key does not have an active OpenCode Go entitlement (HTTP 403)") from exc
        raise RuntimeError(f"OpenCode Go usage request failed (HTTP {exc.code})") from exc
    except urllib.error.URLError as exc:
        reason = getattr(exc, "reason", exc)
        raise RuntimeError(f"Could not reach OpenCode Go: {reason}") from exc

    if not isinstance(payload, dict) or not isinstance(payload.get("usage"), dict):
        raise ValueError("OpenCode Go returned an unexpected usage response")

    usage = payload["usage"]
    return {
        "ok": True,
        "windows": {
            "rolling": normalize_window(usage.get("rolling"), 300),
            "weekly": normalize_window(usage.get("weekly"), 10080),
            "monthly": normalize_window(usage.get("monthly"), 43200),
        },
    }


def main() -> int:
    try:
        api_key, source = find_api_key()
        result = fetch_usage(api_key)
        result["authSource"] = source
        print(json.dumps(result, separators=(",", ":")))
        return 0
    except Exception as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, separators=(",", ":")))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
