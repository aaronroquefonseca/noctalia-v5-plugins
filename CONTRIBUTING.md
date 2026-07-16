# Contributing

## Structure

Keep every plugin self-contained in a top-level directory. Required metadata lives in `plugin.toml`; entry files and translations use paths relative to that manifest.

Do not place runtime state, generated Python bytecode, editor files, or installed plugin copies in the repository.

## Validation

Run before committing:

```bash
python3 scripts/validate.py
noctalia plugins lint .
```

`scripts/validate.py` verifies manifests, IDs, entry files, translation JSON, Python syntax, and catalog synchronization.

## Versions

Use semantic versions in each `plugin.toml`. Increment the affected plugin version for user-visible behavior changes. Keep `catalog.toml` synchronized with the manifest.

## Compatibility

The plugin API is currently beta. Keep `min_noctalia` accurate and test against the declared minimum whenever possible.

## Safety

- Quote user-controlled paths passed to shell commands.
- Bound process timeouts and result counts.
- Validate block devices immediately before mount, unmount, or power-off actions.
- Never store tokens, credentials, or private usage data in the repository.
