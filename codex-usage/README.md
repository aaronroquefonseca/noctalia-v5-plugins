# Noctalia Codex Usage — v5

Native, Quickshell-free Noctalia v5 plugin showing the remaining OpenAI Codex 5-hour and weekly usage limits.

## Features

- Native Noctalia v5 Luau service, bar widget, and panel
- Full, usage-only, and icon-only bar modes
- Both limits, 5-hour only, or weekly only
- Remaining-usage meters and reset times
- Credits and expandable usage-limit reset details with expiration dates
- Automatic and manual refresh
- Optional custom Codex executable path
- Uses the official local `codex app-server --stdio` protocol

## Requirements

- Noctalia 5.0.0 or newer
- Python 3
- OpenAI Codex CLI logged into a ChatGPT account

Verify Codex first:

```bash
codex --version
codex login status
```

## Install this branch

```bash
git clone --branch noctalia-v5 --single-branch \
  https://github.com/aaronroquefonseca/noctalia-codex-usage.git
cd noctalia-codex-usage
bash install.sh
```

The installer copies the plugin to:

```text
${NOCTALIA_DATA_HOME:-${XDG_DATA_HOME:-~/.local/share}}/noctalia/plugins/codex-usage
```

It also runs Noctalia's native offline linter when the `noctalia` executable is available.

After installation:

1. Restart or reload Noctalia.
2. Open **Plugins** and enable `aaronroquefonseca/codex-usage`.
3. Add its `bar` widget to the desired bar section.
4. Click the widget to open the native details panel.

## Update

```bash
cd noctalia-codex-usage
git pull
bash install.sh
```

## Test the data helper

```bash
python3 ~/.local/share/noctalia/plugins/codex-usage/codex_usage.py \
  --codex "$(command -v codex)"
```

A successful response begins with:

```json
{"ok":true,"account":...
```

## Settings

Noctalia generates the settings interface from `plugin.toml`:

- Bar appearance: Codex and usage, usage only, or icon only
- Usage values: both windows, 5-hour only, or weekly only
- Refresh interval: 60–3600 seconds
- Optional explicit Codex executable path

The stable Noctalia v4/QML implementation remains on the `main` branch.

## License

MIT