# Mochi Mart 🍡

A cozy public marketplace for Codex plugins.

## Install

Add the marketplace, install Durable Plan, and enable lifecycle hooks:

```bash
codex plugin marketplace add rktoomey/mochi-mart
codex plugin add durable-plan@mochi-mart
codex features enable hooks
```

Start a new interactive Codex session, run `/hooks`, inspect the two
`durable-plan` definitions, and trust only those definitions. The installer
script performs the same supported CLI workflow:

```bash
scripts/install-durable-plan
```

Codex supports Git-backed marketplace sources such as `owner/repo`, so the
GitHub repository is the update channel. Refresh it with:

```bash
codex plugin marketplace upgrade mochi-mart
codex plugin add durable-plan@mochi-mart
```

## Durable Plan

Durable Plan keeps Plan-mode exploration in the conversation and writes only
a decision-complete final plan. Final plans are stored at:

```text
${CODEX_HOME:-${HOME}/.codex}/plans/<repository>/<slug>.md
```

After saving a plan, the plugin displays a copyable command that opens a new,
interactive Terra session in the implementation repository. The planning
session stays available and the plugin never launches Terra automatically.

Draft planning responses do not write files. Re-emitting an identical final
plan does not replace the canonical file.

See [the design document](docs/durable-plan-design.md) for the persistence
contract, path handling, and failure behavior.

## Security

Durable Plan installs executable lifecycle hooks. Review them through
`/hooks` before trusting them. The installer does not edit Codex configuration
directly and never bypasses hook trust.

Plans are written beneath `CODEX_HOME` with private directory permissions.
The hook validates plan slugs, resolves the active Git root, and writes final
plans atomically.

## Development

Run the complete local checks with:

```bash
tests/run.sh
```

The test suite requires Bash, Git, jq, ripgrep, ShellCheck, and shfmt.

## License

[MIT](LICENSE)
