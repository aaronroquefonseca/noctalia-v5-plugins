# Web Search for Noctalia v5

Search from Noctalia's launcher and open results in the system default browser.

## Usage

Type `/web your query` and activate the result.

Default engine: Startpage. Google, DuckDuckGo, and a custom URL template are available in plugin settings.

Custom templates use `{query}` for the percent-encoded query:

```text
https://search.example/?q={query}
```

## Install

```bash
bash install.sh
```
