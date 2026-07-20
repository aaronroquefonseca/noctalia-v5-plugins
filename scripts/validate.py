#!/usr/bin/env python3
"""Validate manifests, entries, translations, Python, and source catalog."""

from __future__ import annotations

import json
import pathlib
import py_compile
import sys
import tomllib

ROOT = pathlib.Path(__file__).resolve().parent.parent
ENTRY_KINDS = ("service", "widget", "panel", "launcher_provider", "shortcut", "desktop_widget")
CATALOG_FIELDS = (
    "id", "name", "version", "plugin_api", "author", "license", "icon",
    "description", "min_noctalia", "tags",
)


def fail(message: str) -> None:
    raise ValueError(message)


def main() -> int:
    manifests = sorted(ROOT.glob("*/plugin.toml"))
    if not manifests:
        fail("No plugin manifests found")

    expected_catalog: dict[str, dict] = {}
    for path in manifests:
        with path.open("rb") as handle:
            manifest = tomllib.load(handle)
        plugin_id = manifest.get("id")
        if not isinstance(plugin_id, str) or "/" not in plugin_id:
            fail(f"{path}: invalid id")
        if plugin_id in expected_catalog:
            fail(f"Duplicate plugin id: {plugin_id}")
        for required in ("name", "version", "min_noctalia", "author"):
            if not manifest.get(required):
                fail(f"{path}: missing {required}")
        if not isinstance(manifest.get("plugin_api"), int) or manifest["plugin_api"] < 1:
            fail(f"{path}: plugin_api must be a positive integer")
        for kind in ENTRY_KINDS:
            for entry in manifest.get(kind, []):
                target = path.parent / entry["entry"]
                if not target.is_file():
                    fail(f"{path}: missing {kind} entry {target}")
        translations = path.parent / "translations"
        if translations.is_dir():
            for translation in translations.glob("*.json"):
                with translation.open(encoding="utf-8") as handle:
                    json.load(handle)
        for script in path.parent.rglob("*.py"):
            py_compile.compile(str(script), doraise=True)
        expected_catalog[plugin_id] = {
            field: manifest.get(field, "MIT" if field == "license" else ([] if field == "tags" else ""))
            for field in CATALOG_FIELDS
        }

    with (ROOT / "catalog.toml").open("rb") as handle:
        catalog = tomllib.load(handle)
    actual_catalog = {item["id"]: item for item in catalog.get("plugin", [])}
    if set(actual_catalog) != set(expected_catalog):
        fail("catalog.toml plugin IDs do not match manifests")
    for plugin_id, expected in expected_catalog.items():
        actual = actual_catalog[plugin_id]
        for field, value in expected.items():
            if actual.get(field) != value:
                fail(f"catalog.toml: {plugin_id}.{field} differs from plugin.toml")

    print(f"Validated {len(manifests)} plugins.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError, json.JSONDecodeError, tomllib.TOMLDecodeError, py_compile.PyCompileError) as error:
        print(f"Validation failed: {error}", file=sys.stderr)
        raise SystemExit(1)
