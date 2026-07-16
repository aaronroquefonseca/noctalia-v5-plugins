#!/usr/bin/env python3
"""Run an interactive updater independently and persist its completion state."""

from __future__ import annotations

import argparse
import fcntl
import json
import os
from pathlib import Path
import subprocess
import time


def write_state(path: Path, state: dict[str, object]) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(state), encoding="utf-8")
    os.replace(temporary, path)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--state", required=True)
    parser.add_argument("--command", required=True)
    args = parser.parse_args()

    state_path = Path(args.state)
    state_path.parent.mkdir(parents=True, exist_ok=True)
    lock_path = state_path.with_suffix(state_path.suffix + ".lock")

    with lock_path.open("w", encoding="utf-8") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return 75

        started_at = int(time.time())
        write_state(state_path, {"running": True, "startedAt": started_at})
        result = subprocess.run(args.command, shell=True, check=False)
        write_state(
            state_path,
            {
                "running": False,
                "startedAt": started_at,
                "finishedAt": int(time.time()),
                "exitCode": result.returncode,
            },
        )
        return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
