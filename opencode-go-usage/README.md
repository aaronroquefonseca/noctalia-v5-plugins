# Noctalia OpenCode Go Usage — v5

Native Noctalia v5 plugin showing remaining OpenCode Go subscription usage.

## Features

- 5-hour, weekly, and monthly quota windows
- Remaining-usage meters and reset countdowns
- Over/under even-pace indicators
- Full, usage-only, and icon-only bar modes
- Automatic refresh every five minutes by default
- Right-click the bar widget to refresh immediately
- Uses OpenCode's account-wide Go usage endpoint
- Automatically reads the API key from `OPENCODE_API_KEY` or OpenCode's local `auth.json`

## Install

Add this repository as a Noctalia plugin source, then enable:

```text
aaronroquefonseca/opencode-go-usage
```

Add `aaronroquefonseca/opencode-go-usage:bar` to a bar. Click it for details.

OpenCode Go should already be connected. If not:

```bash
opencode auth login -p opencode-go
```

The helper never prints or stores the API key.

## Data source

The plugin requests:

```text
GET https://opencode.ai/zen/go/v1/usage
```

with the same API key OpenCode uses. The response provides the rolling 5-hour, weekly, and monthly used percentages and reset timestamps; the plugin converts those values to percentage remaining to match the Codex Usage plugin.

## License

MIT
