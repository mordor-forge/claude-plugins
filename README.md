# mordor-forge Claude Code plugins

[![Validate](https://github.com/mordor-forge/claude-plugins/actions/workflows/validate.yml/badge.svg)](https://github.com/mordor-forge/claude-plugins/actions/workflows/validate.yml)

The `mordor-forge` plugin marketplace for Claude Code. This repository only holds the catalog; each plugin lives in its own repository.

```text
/plugin marketplace add mordor-forge/claude-plugins
/plugin install gemini-media@mordor-forge
/plugin install trident@mordor-forge
```

| Plugin | Repository | What it does |
| --- | --- | --- |
| `gemini-media` | [gemini-media-mcp](https://github.com/mordor-forge/gemini-media-mcp) | Images, video, speech and music with Google's Gemini media models |
| `trident` | [trident-mcp](https://github.com/mordor-forge/trident-mcp) | 3D generation and processing with the Tripo 3D API |

Both plugins run a local MCP server binary, which must be on your `PATH`. See each repository's README for install options.

## Migrating from the old marketplace source

If you added `mordor-forge` from `mordor-forge/gemini-media-mcp`, switch to this catalog:

```text
/plugin marketplace remove mordor-forge
/plugin marketplace add mordor-forge/claude-plugins
```

## Adding a plugin

1. Add an entry to `.claude-plugin/marketplace.json` with a `url` source pointing at the plugin's repository. Keep the entries sorted by name.
2. Make sure the plugin repository has `.claude-plugin/plugin.json` at its root, and that its `name` matches the entry.
3. Pin a `ref` (tag) or `sha` when a release should stay fixed. Without one, users get the default branch.
4. Run `scripts/validate-marketplace.sh --plugins`. It needs `jq`, plus the `claude` CLI or `npx`.

## CI

`.github/workflows/validate.yml` runs on pushes to `main`, on pull requests, weekly, and on demand:

| Job | Checks |
| --- | --- |
| `catalog` | Catalog structure (unique, sorted, kebab-case names; remote sources) and `claude plugin validate .` with the current Claude Code release |
| `plugins` | Clones every listed plugin at its pinned ref and validates its manifest. The weekly run catches plugins that break after they are listed |
| `workflows` | `actionlint`, and a `zizmor` security audit of the workflows |
| `links` | `lychee` link check over the Markdown |

Actions are pinned to commit SHAs. Dependabot keeps them current, with a 7-day cooldown.
