# Durable Plan Plugin Design

## Status

Approved in conversation on 2026-07-16.

## Purpose

Make Codex Plan mode produce one durable, decision-complete Markdown plan
without turning every intermediate planning response into a file update. After
the plan is saved, show a copyable command that starts a new interactive Terra
session in the same repository and asks it to implement the plan.

The workflow is intended for long-running Sol planning sessions followed by a
separate, steerable Terra implementation session.

## User Experience

1. The operator starts Codex with Sol and enters Plan mode.
2. Sol investigates, asks questions, and revises the design in the existing
   conversation. Draft responses are not written to disk.
3. When every implementation-affecting decision is settled, Sol emits a final
   Markdown plan.
4. A Stop hook saves that final plan to:

   ```text
   ~/.codex/plans/<repo>/<slug>.md
   ```

5. The hook reports the saved path and displays an exact command shaped like:

   ```bash
   codex -m gpt-5.6-terra -C <repo-root> \
     "Implement <plan-path>. Verify live repository state before editing."
   ```

6. The operator runs the command in a terminal. Because it invokes `codex`, not
   `codex exec`, it opens a new interactive session that can be discussed and
   steered normally.

The Sol session remains available. The plugin never launches Terra by itself.

## Decision-Complete Contract

The plugin injects a short protocol into every Plan-mode turn with a
`UserPromptSubmit` hook. The protocol requires the assistant response to end
with exactly one invisible marker:

```html
<!-- durable-plan: draft -->
```

or:

```html
<!-- durable-plan: final slug=<slug> -->
```

`draft` means that questions, investigation, or implementation-affecting
decisions remain. `final` means all required decisions are settled and another
engineer can implement the plan without making new design choices.

For a final response:

- the complete response before the marker is the canonical Markdown document;
- there is no conversational preamble outside the document;
- the slug matches `^[a-z0-9][a-z0-9-]{0,79}$`;
- the plan identifies scope, repository state to verify, implementation steps,
  testing, and acceptance criteria;
- unresolved decisions are forbidden.

The marker is an HTML comment so it is not visually noisy in normal Markdown
rendering. The saved file does not contain the marker.

## Architecture

The implementation is a public Codex plugin stored in the Mochi Mart
marketplace repository. It contains lifecycle hooks but no skill. Plan mode owns
the planning conversation; the plugin only adds a deterministic persistence
contract and handoff command.

The Mochi Mart repository is a Git-backed plugin marketplace:

```text
.agents/plugins/marketplace.json
plugins/durable-plan/
  .codex-plugin/plugin.json
  hooks/hooks.json
  hooks/durable-plan
scripts/install-durable-plan
tests/test-durable-plan-hooks.sh
tests/test-install-durable-plan.sh
```

Codex discovers `hooks/hooks.json` through the standard plugin layout, so the
manifest does not duplicate that path. Both hook events invoke the same Bash
entrypoint, which dispatches on `hook_event_name`. Keeping one entrypoint avoids
duplicated parsing, validation, and error behavior.

The implementation uses Bash, `git`, and `jq`. It does not use Python, Node.js,
or the unstable transcript format.

## Hook Behavior

### `UserPromptSubmit`

The hook reads one JSON object from standard input.

- If `permission_mode` is not `plan`, it exits successfully with no output.
- If `permission_mode` is `plan`, it returns
  `hookSpecificOutput.additionalContext` containing the decision-complete
  contract and marker syntax.

The context is deliberately short and stable. Repeating it on Plan-mode turns
is necessary because a Stop hook cannot safely infer whether a response is a
draft or a final plan.

### `Stop`

The hook reads `permission_mode`, `last_assistant_message`,
`stop_hook_active`, and `cwd` from standard input.

- Outside Plan mode, it exits successfully with no output.
- A terminal `draft` marker causes no file write.
- A valid terminal `final` marker causes the plan to be validated and saved.
- A missing or malformed marker blocks stopping once and asks the assistant to
  re-emit the response with a valid marker.
- If `stop_hook_active` is already true, the hook reports the failure and does
  not block again. This prevents an infinite continuation loop.

The hook only accepts a marker at the end of the assistant message. Marker-like
text inside examples or earlier prose has no effect.

## Repository and Path Resolution

The hook treats the session `cwd` as untrusted input and resolves the Git root
with:

```bash
git -C "${cwd}" rev-parse --show-toplevel
```

The repository key is the basename of the `origin` remote with a trailing
`.git` removed. Both SSH and HTTPS Git remotes are supported. If `origin` does
not exist, the Git root basename is used. Normalization lowercases the value,
replaces each run of characters outside `[a-z0-9]` with one hyphen, and trims
leading and trailing hyphens. An empty result is rejected.

The assistant controls only the validated slug, never a path. The hook joins
the fixed plans root, derived repository key, and slug. It rejects path
traversal, newlines, absolute paths, and empty components.

`CODEX_HOME` is honored when set. Otherwise the plans root is
`${HOME}/.codex/plans`.

## Writes and Cost Control

Drafts never write. A final plan is written atomically by creating a temporary
file in the destination directory and renaming it into place. The directory is
created under `umask 077`. The canonical file ends with one newline.

If the canonical file already contains identical bytes, the hook performs no
replacement and reports that the plan is unchanged. If a later decision-complete
plan with the same slug differs, it atomically replaces the canonical file.
There is no progress log, version history, or backup file in version 1.

Disk writes are not the material token cost. Regenerating plan text is. This
design avoids model-requested rewrites for intermediate turns and does not ask
the model to regenerate a final plan merely to update metadata. Markdown is
used instead of HTML because it is shorter, directly readable by Codex, and
diff-friendly.

## Terra Launch Command

After a successful or unchanged final save, the hook returns a visible
`systemMessage` with:

- the absolute saved plan path;
- an interactive `codex` command using `gpt-5.6-terra`;
- `-C` set to the resolved Git root;
- an implementation prompt that names the plan and requires live repository
  verification before editing.

Every shell argument is safely quoted for copy and paste. The hook never uses
`eval` and never executes the displayed command.

## Installation

`scripts/install-durable-plan` is an idempotent installer. It:

1. verifies `codex` and `jq` are available;
2. inspects `codex plugin marketplace list --json`;
3. registers `rktoomey/mochi-mart` as the marketplace source when absent;
4. refreshes an existing Mochi Mart marketplace snapshot;
5. installs the current `durable-plan` version with `codex plugin add`;
6. runs `codex features enable hooks`;
7. prints the remaining manual trust step.

The installer never edits `~/.codex/config.toml` directly. It uses supported
Codex CLI commands. It does not pass
`--dangerously-bypass-hook-trust`.

Codex hashes non-managed hook definitions. Installation and enablement do not
trust executable hooks automatically. After installation, the operator must
start an interactive Codex session, run `/hooks`, inspect the durable-plan hook
source, and trust those exact definitions. Other plugin hooks remain
independently disabled or untrusted unless the operator explicitly changes
them.

Rerunning the installer produces the same configured end state and refreshes
the Git-backed marketplace snapshot. Releases update the plugin version through
Plugin Creator's supported workflow. Because an update can change the hook
hash, Codex may require another `/hooks` review. The installer states this
explicitly.

## Failure Behavior

The plugin fails closed for persistence but never fabricates success.

- Invalid JSON, missing `jq`, no Git root, invalid slug, an empty final plan,
  or a failed atomic write produces a visible error and no success message.
- A final plan cannot escape the configured plans root.
- A draft cannot overwrite an existing final plan.
- A failed write leaves the previous canonical plan intact.
- The hook does not read or parse `transcript_path`.
- Hook output never includes repository secrets or environment contents.

## Verification

`tests/test-durable-plan-hooks.sh` exercises the hook with JSON fixtures and a
temporary `HOME`, `CODEX_HOME`, and Git repository. It covers:

- non-Plan mode no-op;
- Plan-mode context injection;
- draft no-op;
- final save and marker removal;
- identical final no-op;
- changed final atomic replacement;
- SSH and HTTPS origin parsing;
- missing origin fallback;
- invalid and traversal-shaped slugs;
- missing and malformed markers;
- the one-retry Stop guard;
- spaces in repository and plan paths;
- safe Terra command quoting;
- failed writes preserving the previous plan.

`tests/test-install-durable-plan.sh` uses fake `codex` and `jq` commands plus a
temporary Codex home. It verifies first install, repeated install, refresh,
feature enablement, prerequisite failure, and the manual `/hooks` instruction.

The repository gates are:

```bash
tests/run.sh
shellcheck plugins/durable-plan/hooks/durable-plan \
  scripts/install-durable-plan \
  tests/test-durable-plan-hooks.sh \
  tests/test-install-durable-plan.sh
shfmt -d -i 2 -ci plugins/durable-plan/hooks/durable-plan \
  scripts/install-durable-plan \
  tests/test-durable-plan-hooks.sh \
  tests/test-install-durable-plan.sh
```

The implementation also validates the plugin and marketplace manifests through
Codex before installation is considered complete.

## Non-Goals

Version 1 does not:

- clear or compact the Sol session;
- automatically launch Terra;
- mutate the implementation repository;
- save intermediate drafts or progress logs;
- generate HTML;
- maintain a plan database or version history;
- infer finality from conversational language;
- bypass Codex hook trust;
- enable or trust unrelated plugin hooks.

## Sources

- [OpenAI Codex hooks](https://learn.chatgpt.com/docs/hooks.md)
- [OpenAI build plugins](https://learn.chatgpt.com/docs/build-plugins.md)
- [OpenAI Codex CLI developer commands](https://learn.chatgpt.com/docs/developer-commands.md)
