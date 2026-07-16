#!/usr/bin/env python3
"""Read Codex usage through the official local `codex app-server` interface."""

from __future__ import annotations

import argparse
import glob
import json
import os
import select
import shutil
import subprocess
import time
from pathlib import Path
from typing import Any

TIMEOUT_SECONDS = 25


def find_codex(explicit: str | None) -> str:
    if explicit:
        path = os.path.expanduser(explicit)
        if os.path.isfile(path) and os.access(path, os.X_OK):
            return path
        resolved = shutil.which(explicit)
        if resolved:
            return resolved
        raise FileNotFoundError(f"Codex executable not found: {explicit}")

    resolved = shutil.which("codex")
    if resolved:
        return resolved

    home = str(Path.home())
    candidates = [
        f"{home}/.local/bin/codex",
        f"{home}/.npm-global/bin/codex",
        f"{home}/.bun/bin/codex",
        "/usr/local/bin/codex",
        "/usr/bin/codex",
    ]
    candidates.extend(sorted(glob.glob(f"{home}/.nvm/versions/node/*/bin/codex"), reverse=True))
    candidates.extend(sorted(glob.glob(f"{home}/.local/share/mise/installs/node/*/bin/codex"), reverse=True))

    for candidate in candidates:
        if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate
    raise FileNotFoundError("Codex CLI was not found. Install Codex or set its path in plugin settings.")


def normalize(account_result: dict[str, Any] | None, usage: dict[str, Any]) -> dict[str, Any]:
    rate_limits = usage.get("rateLimits") or {}
    by_id = usage.get("rateLimitsByLimitId") or {}
    additional = [value for key, value in by_id.items() if key != "codex"]

    account = account_result.get("account") if account_result else None
    return {
        "ok": True,
        "account": account,
        "rateLimits": rate_limits,
        "additionalRateLimits": additional,
        "resetCredits": usage.get("rateLimitResetCredits"),
    }


def write_message(process: subprocess.Popen[str], message: dict[str, Any]) -> None:
    if process.stdin is None:
        raise RuntimeError("Codex app-server stdin is unavailable")
    process.stdin.write(json.dumps(message, separators=(",", ":")) + "\n")
    process.stdin.flush()


def read_response(process: subprocess.Popen[str], request_id: int, deadline: float) -> dict[str, Any]:
    if process.stdout is None:
        raise RuntimeError("Codex app-server stdout is unavailable")

    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise subprocess.TimeoutExpired(process.args, TIMEOUT_SECONDS)

        ready, _, _ = select.select([process.stdout], [], [], remaining)
        if not ready:
            raise subprocess.TimeoutExpired(process.args, TIMEOUT_SECONDS)

        raw_line = process.stdout.readline()
        if raw_line == "":
            stderr = process.stderr.read().strip() if process.stderr else ""
            detail = f": {stderr}" if stderr else ""
            raise RuntimeError(f"Codex app-server exited before response {request_id}{detail}")

        try:
            message = json.loads(raw_line)
        except json.JSONDecodeError:
            continue

        if message.get("id") != request_id:
            continue
        if "error" in message:
            error = message.get("error") or {}
            raise RuntimeError(error.get("message", f"Codex request {request_id} failed"))
        return message.get("result") or {}


def query(codex: str) -> dict[str, Any]:
    env = os.environ.copy()
    env.setdefault("RUST_LOG", "error")
    process = subprocess.Popen(
        [codex, "app-server", "--stdio"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
        env=env,
    )
    deadline = time.monotonic() + TIMEOUT_SECONDS

    try:
        write_message(process, {
            "method": "initialize",
            "id": 1,
            "params": {
                "clientInfo": {
                    "name": "noctalia_codex_usage",
                    "title": "Noctalia Codex Usage",
                    "version": "1.0.0",
                }
            },
        })
        read_response(process, 1, deadline)

        write_message(process, {"method": "initialized", "params": {}})
        write_message(process, {
            "method": "account/read",
            "id": 2,
            "params": {"refreshToken": True},
        })
        account = read_response(process, 2, deadline)

        write_message(process, {
            "method": "account/rateLimits/read",
            "id": 3,
            "params": {},
        })
        usage = read_response(process, 3, deadline)
        return normalize(account, usage)
    finally:
        if process.stdin:
            process.stdin.close()
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=2)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--codex", help="Path or command name for the Codex CLI")
    args = parser.parse_args()
    try:
        result = query(find_codex(args.codex))
        print(json.dumps(result, separators=(",", ":")))
        return 0
    except subprocess.TimeoutExpired:
        error = f"Codex app-server did not respond within {TIMEOUT_SECONDS} seconds"
    except Exception as exc:
        error = str(exc)

    print(json.dumps({"ok": False, "error": error}, separators=(",", ":")))
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
