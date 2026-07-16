# Aaron's Noctalia v5 Plugins

Native [Noctalia v5](https://docs.noctalia.dev/v5/) plugins written for the Quickshell-free Luau plugin runtime.

This repository is a Noctalia plugin source: add the repository once, then enable and update individual plugins from Noctalia's plugin settings.

## Plugins

| Plugin | Type | Description | Main dependencies |
| --- | --- | --- | --- |
| Codex Usage | Bar, panel, service | Shows Codex five-hour and weekly usage limits, reset times, credits, and errors. | `python3`, `codex` |
| Arch Updater | Bar, panel, service | Checks Arch, AUR, and optional Flatpak updates and launches a configurable updater. | `pacman-contrib`; optionally `yay`, `flatpak` |
| Web Search | Launcher | Searches Startpage, Google, DuckDuckGo, or a custom engine in the default browser. | `xdg-utils` |
| File Search | Launcher | Searches configured folders using `fd` and opens files or folders with configurable commands. | `fd`, `python3`, `xdg-utils` |
| USB Drive Manager | Bar, panel, service | Mounts, opens, unmounts, and safely powers off removable USB filesystems. | `udisks2`, `util-linux`, `python3` |

## Install as a plugin source

After this repository has been published, add it from **Settings → Plugins → Add source**, or use:

```bash
noctalia msg plugins source add aarons-plugins git https://github.com/aaronroquefonseca/noctalia-v5-plugins
```

Then enable any plugin in Noctalia. Plugin IDs:

```text
aaronroquefonseca/codex-usage
aaronroquefonseca/arch-updater
aaronroquefonseca/web-search
aaronroquefonseca/file-search
aaronroquefonseca/usb-drive-manager
```

Update the source with:

```bash
noctalia msg plugins update aarons-plugins
```

## Usage

### Codex Usage

Add `aaronroquefonseca/codex-usage:bar` to a bar. Click for details; right-click to refresh.

### Arch Updater

Add `aaronroquefonseca/arch-updater:bar` to a bar. Click for available packages. Review the configured update command before running it.

### Web Search

Open the launcher and type:

```text
/web your search
```

Startpage is the default. Search engine and custom URL template are configurable.

### File Search

Open the launcher and type:

```text
/files filename
```

Search roots, hidden-file handling, result count, and file/folder openers are configurable.

### USB Drive Manager

Add `aaronroquefonseca/usb-drive-manager:bar` to a bar. Click to mount, open, unmount, or safely remove connected removable storage.

Safe removal unmounts every mounted filesystem on the parent disk before requesting UDisks power-off.

## Repository layout

```text
.
├── catalog.toml
├── scripts/
│   └── validate.py
├── codex-usage/
├── arch-updater/
├── web-search/
├── file-search/
└── usb-drive-manager/
```

Each plugin directory is self-contained and starts with `plugin.toml`. `catalog.toml` provides source-level discovery metadata; plugin manifests remain authoritative.

## Development

Requirements: Noctalia `5.0.0+`, Python `3.11+`.

Run all repository checks:

```bash
python3 scripts/validate.py
noctalia plugins lint .
```

For local development, add this checkout as a path source:

```bash
noctalia msg plugins source add aarons-dev path "$PWD"
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for release and validation rules.

## Security

Noctalia plugins are trusted code. Review scripts and commands before enabling plugins. Device operations are limited to block devices currently identified by `lsblk` as USB, removable, or hot-pluggable.

## License

MIT. Individual plugin directories may include additional attribution or license files.
