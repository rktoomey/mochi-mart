# Mochi Mart Codex Extension Roadmap

> Status: Research brief and product decision record. Phase 1 is selected,
> but implementation must not begin until the remaining design gates are
> resolved.

## Goal

Identify recurring Codex CLI complaints that can be addressed honestly through
plugins, lifecycle hooks, skills, MCP servers, or companion terminal tooling,
then prioritize the smallest useful Mochi Mart products.

## Research Window

The research covers public activity from 2026-06-16 through 2026-07-16.

The review included:

- 3,826 `openai/codex` issues opened during the window;
- 5,714 `openai/codex` issues updated during the window;
- the top 100 newly opened issues by interactions;
- the top 100 newly opened issues by reactions;
- targeted GitHub searches for status lines, compaction, subagents, session
  handling, approvals, LSP support, and usage visibility;
- date-bounded Reddit searches across `r/codex`.

Reddit search indexing is incomplete. Reddit evidence is corroborating
qualitative signal, not a complete population count.

## Product Decisions

1. Build `mochi-bar` before the other opportunities.
2. `mochi-bar` augments Codex with a second terminal-owned status line beneath
   the official footer. It does not patch or replace Codex's renderer.
3. The official footer remains responsible for model, context, and quota
   fields already supported by `/statusline`.
4. Mochi Mart code uses documented hooks and normal Git or shell interfaces.
   It must not parse unstable transcripts, read private Codex databases, read
   authentication files, or reverse-engineer compiled assets.
5. The first status line focuses on workflow state that Codex does not expose
   well: current phase, agent activity, last tool, checkpoint freshness,
   repository state, elapsed time, and attention requirements.
6. Compaction continuity is the second product area. Agent orchestration is
   third.

## Opportunity Ranking

### 1. Mochi Bar

**Problem:** Codex `/statusline` supports predefined items but not arbitrary
command-backed content, conditional indicators, custom formatting, or external
workflow state.

**Evidence:**

- [Customizable status line](https://github.com/openai/codex/issues/17827)
  has 29 comments. Recent comments explicitly request command-backed content,
  semantic colors, conditional display, and cross-session workflow badges.
- [Support multi-line status line](https://github.com/openai/codex/issues/21653)
  has 11 comments and documents truncation when several built-in fields are
  enabled.
- [Expose rate-limit reset times, balance, and plan](https://github.com/openai/codex/issues/24080)
  has 10 comments and shows demand for richer persistent information.
- Reddit users explicitly compare Codex with CCStatusLine in
  [this workflow discussion](https://www.reddit.com/r/codex/comments/1ug1jy8/really_appreciate_what_codex_has_done_recently/).
- The community is already building external visibility tools such as
  [Codelight](https://www.reddit.com/r/codex/comments/1urqn6q/i_built_an_opensource_dashboard_for_codex_status/).

**Proposed user experience:**

```text
official Codex footer
🍡 implementing · 2 agents · tests running · checkpoint 3m · main*
```

**Candidate Phase 1 fields:**

- current permission or collaboration mode;
- active workflow phase;
- active subagent count;
- last lifecycle event or tool;
- Git branch and clean or dirty state;
- elapsed session time;
- checkpoint age;
- waiting-for-question or waiting-for-approval indicator.

**Proposed architecture:**

- a launcher reserves one terminal-owned line below the Codex TUI;
- plugin lifecycle hooks publish supported session events to a small JSON
  state file;
- a renderer reads the state file and formats one bounded line;
- stale state expires visibly instead of being presented as current;
- failure of the renderer never blocks or terminates Codex.

**Documented hook inputs available for Phase 1:**

- session identifier;
- working directory;
- active model;
- permission mode;
- lifecycle event;
- tool and subagent lifecycle fields on the corresponding events.

**Non-goals for Phase 1:**

- replacing the official Codex footer;
- scraping token or quota values from private state;
- modifying Codex binaries or source;
- changing native subagent behavior;
- supporting arbitrary multiline dashboards.

**Acceptance criteria:**

- the extra line remains visible while Codex redraws its TUI;
- hooks update the line after prompts, tools, compaction, and subagent
  lifecycle events;
- the line never consumes prompt context;
- disabling the plugin restores ordinary Codex behavior;
- no private or unstable Codex state is required;
- status rendering remains useful at narrow terminal widths;
- installation and removal are documented and reversible.

### 2. Compaction Continuity

**Problem:** Long-running sessions can lose recent decisions, rejected
approaches, touched files, and verification state after compaction.

**Evidence:**

- [Context compaction loses operational continuity](https://github.com/openai/codex/issues/29356)
  has 18 comments and describes repeated work, drift, and forgotten
  constraints.
- Reddit reports include
  [context compaction is completely broken](https://www.reddit.com/r/codex/comments/1uy70sl/context_compactment_is_completely_broken/)
  and
  [5.6 goes dumb after compaction](https://www.reddit.com/r/codex/comments/1uvmngz/56_goes_dumb_after_compaction/).

**Monkey-patch shape:** A skill maintains a compact operational checkpoint.
Hooks reinject it after compaction or resume, and Mochi Bar shows its age.
Semantic checkpoint quality still depends on the model updating the artifact;
a command hook cannot independently reconstruct intent.

Durable Plan already covers the planning-to-implementation boundary. This
opportunity extends continuity through implementation.

### 3. Transparent Agent Cockpit

**Problem:** Users cannot reliably see or control the model, reasoning effort,
task, context use, and lifecycle of native subagents.

**Evidence:**

- [Sol cannot specify subagent models](https://github.com/openai/codex/issues/31814)
  received 96 comments before closing.
- [The CLI lacks an active-agent thread selector](https://github.com/openai/codex/issues/30813)
  remains open.
- Reddit requests
  [more subagent transparency](https://www.reddit.com/r/codex/comments/1ut1cy4/we_need_more_transparency_around_codex_subagents/)
  and reports that the
  [CLI no longer shows subagent models](https://www.reddit.com/r/codex/comments/1usdgha/codex_cli_no_longer_shows_subagents_model/).

**Monkey-patch shape:** Launch explicit, independently steerable Codex
sessions with known model and reasoning settings in separate terminal panes.
Track them through a shared state registry and Mochi Bar. Do not claim to fix
native MultiAgent V2.

### 4. No-Countdown Questions and Attention Relay

**Problem:** Plan-mode questions can auto-resolve after 60 seconds, and users
lack a persistent, low-noise indication that Codex needs attention.

**Evidence:**

- [Disable 60-second auto-resolution](https://github.com/openai/codex/issues/28969)
  has 38 comments.
- [Codelight](https://www.reddit.com/r/codex/comments/1urqn6q/i_built_an_opensource_dashboard_for_codex_status/)
  received positive attention for surfacing status and remote prompts.

**Monkey-patch shape:** Inject a rule that blocking design questions must be
asked as ordinary messages instead of timed selectors. Hooks update Mochi Bar
and terminal notifications when attention is required. This avoids the timed
surface; it does not disable the core timer.

### 5. LSP Bridge

**Problem:** Codex lacks built-in language-server diagnostics, definitions,
references, and symbol navigation.

**Evidence:**

- [LSP integration for Codex CLI](https://github.com/openai/codex/issues/8745)
  has 56 comments and remained active during the research window.

**Monkey-patch shape:** Bundle an MCP server that connects to already-installed
language servers. Initial work must avoid automatic installation across many
languages. Existing ecosystem tools must be evaluated before building.

### 6. Session Bridge and File Checkpoints

**Problem:** Users want structured context transfer between sessions and a way
to recover from unintended edits.

**Evidence:**

- [`/merge` session context](https://github.com/openai/codex/issues/29031)
  requests a first-class session import path.
- [Restore `/undo`](https://github.com/openai/codex/issues/9203)
  has 55 comments.

**Monkey-patch shape:** Skills can export and import explicit handoff packets.
Hooks can snapshot file diffs outside the repository before edit operations.
This can provide file recovery but cannot undo conversation state.

## Complaints Explicitly Excluded

The highest-volume complaint clusters were rapid quota consumption, Windows
application crashes, sandbox regressions, and malformed native tool calls.
These require service or core-client fixes. Mochi Mart must not advertise a
plugin as a fix for them.

## Phase 1 Design Gates

Resolve these before writing an implementation plan:

1. Choose the terminal carrier: tmux-backed first release or a dedicated PTY
   wrapper.
2. Choose supported platforms for version 0.1.
3. Define the exact one-line state schema and maximum refresh frequency.
4. Decide whether Mochi Bar is an independent plugin or a companion component
   bundled with Durable Plan.
5. Decide how installation behaves when the required terminal carrier is
   absent.

After these decisions are complete, write a separate implementation plan for
`mochi-bar`. Do not combine compaction continuity, agent orchestration, LSP,
or session recovery into the Phase 1 implementation.

## Official Capability References

- [Codex lifecycle hooks](https://learn.chatgpt.com/docs/hooks.md)
- [Build Codex plugins](https://learn.chatgpt.com/docs/build-plugins.md)
- [Codex CLI developer commands](https://learn.chatgpt.com/docs/developer-commands.md)
