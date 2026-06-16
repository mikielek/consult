---
name: consult
description: Consult another coding agent — Gemini, OpenCode, Claude, Codex, Pi, or any backend you add — as an independent second opinion. Use when the user asks to involve, ask, consult, cross-check, compare with, brainstorm with, or get a second opinion from another agent or model (e.g. "ask Gemini", "ask Claude", "ask Codex", "cross-check with OpenCode", "ask Pi"), or when a hard problem would benefit from an outside perspective — design or concept review, code review, debugging, risk analysis, architecture tradeoffs, or brainstorming. Routes to a pluggable backend via scripts/consult.sh; run it with --list to see who is available. Supports headless prompts, JSON output, model selection, and session continuity, defaulting to read-only, approval-gated, or tool-allowlisted modes. Verify the consulted agent's claims locally before acting on them.
license: Apache-2.0
metadata:
  version: 1.0.0
---

# Consult

## Overview

Bring an external coding agent into the current task as an independent reviewer or design partner.
A single dispatcher routes to a pluggable backend, so the same workflow works whether the user wants
Gemini, OpenCode, Claude, Codex, Pi, or another agent. Treat any response as **advice**: verify
repo-specific claims yourself before changing code or reporting conclusions.

This is not only for plans. Consult for any kind of help: design/concept review, code review,
debugging, risk analysis, architecture tradeoffs, brainstorming, or a plain second opinion.

## Pick a backend

The user usually names one ("ask Gemini", "cross-check with OpenCode"). If they don't, list what is
installed and ask which to use (or pick the only one available):

```bash
<skill-dir>/scripts/consult.sh --list
```

`<skill-dir>` is this skill's base directory (your host tells you where the skill lives at load time
— e.g. `.agents/skills/consult`, or `.claude/skills/consult` / `.codex/skills/consult` if symlinked
there). Backends are dynamic — whatever scripts exist under `scripts/backends/` are available.
`--list` also shows which backend CLIs are **installed** (on PATH). Note "installed" ≠ authenticated:
consulting a missing CLI fails instantly with a clear message; an unauthenticated one either fails
fast (stdin is closed) or may stall on browser/network auth — so run with existing auth outside any
sandbox.

## Run a consultation

Keep your shell at the **project root** (so the backend sees the repo being discussed) and invoke the
dispatcher by its full path under the skill — `<skill-dir>/scripts/consult.sh`. The script resolves
its own location, so it works regardless of the working directory.

```bash
<skill-dir>/scripts/consult.sh --to gemini --prompt "<your consultation>"
```

Preview the exact backend command without executing (useful to confirm or to show the user):

```bash
<skill-dir>/scripts/consult.sh --to gemini --dry-run --prompt "<your consultation>"
```

Request machine-readable output when the response will be parsed or logged:

```bash
<skill-dir>/scripts/consult.sh --to opencode --json --prompt "Return exactly three risks as bullets."
```

Identify yourself with `--from <your-agent-name>` so the consulted agent has framing; the dispatcher
defaults it to "a coding agent". Use `--model`, `--file` (backend permitting), or `--raw` (send the
prompt verbatim, skipping the reviewer framing) as needed. There is no `--`/passthrough — only the
documented flags are accepted. See `<skill-dir>/scripts/consult.sh --help`.

## What to ask for

Give enough context for the backend to answer independently, and ask for a concrete deliverable.
The dispatcher wraps your prompt with a neutral read-only reviewer framing; you supply the substance:

```text
Goal: <what you want help with>.
Context: <files, errors, command output, design notes, or constraints>.
Return: <the deliverable below>.
```

Match the deliverable to the kind of consultation:

- **Code review** → severity-ordered findings with file:line references.
- **Design / concept review** → tradeoffs, failure modes, and the smallest useful next experiment.
- **Brainstorm** → a few divergent options, then a recommendation.
- **Debugging** → ranked hypotheses plus reproduction / diagnostic steps.

## Session continuity

- One-shot prompt for a single review, quick check, or standalone answer.
- One persistent session for multi-round consultation, debate, iterative design, or continued review
  on the same topic. If the user asked to consult but did not say whether it is one-shot or ongoing,
  ask before the first call.
- Continue a session with `--resume latest` (only when no unrelated session intervened) or
  `--resume <session-id>`. Gemini, Claude, and Pi also accept `--session-id <uuid>` to start an
  explicit session; OpenCode and Codex assign their own ids (capture them from output to resume).
- Note a persistent session id in your working notes when later rounds will need it. If the task
  changes materially, start a new session or ask whether to continue.

## Adding or removing a backend

- **Add**: drop a `scripts/backends/<name>.sh` adapter (copy an existing one). It sources
  `scripts/lib/common.sh`, which parses the normalized flags and builds the prompt; the adapter only
  translates them into its CLI and enforces read-only defaults. It is picked up immediately.
- **Remove**: delete that file. No other edits needed.

## Permissions and safety

Consultations are read-only by default, but the strength differs by backend: **Codex is
OS-sandbox-enforced** read-only (`-s read-only -a never`), **Gemini, OpenCode, and Claude are
approval-gated** (`--approval-mode plan` / `--agent plan` / `--permission-mode plan` — no edits
without approval, which is unavailable headless, so effectively read-only but not a hard sandbox),
and **Pi is tool-allowlist/discovery-hardened** (`--tools read,grep,ls` plus disabled extension,
skill, template, theme, context-file, and project-trust discovery, excluding edit/write/bash and
discovered extension/custom tools). Safety is also structural: the adapters accept only the
documented normalized flags (no `--` passthrough), so callers can't inject permission- or
capability-shaping flags, and commands are built as argv arrays with no shell eval.

All backends can still read accessible project files and return their contents. Avoid sending
secrets or unnecessary proprietary data to a third-party agent; summarize sensitive context or ask
the user first.

If your host sandboxes network or auth, run the wrapper outside that sandbox — the CLIs reuse the
user's existing auth and need network access. **OpenAI Codex** users: see
`references/codex-permissions.md` for escalated-execution and prefix-approval guidance.

## Using results

- Extract the concrete claims, risks, or suggested checks.
- Verify them with local file reads, tests, or commands.
- Incorporate only the parts that survive verification.
- Mention the consultation in your final answer when it materially influenced the result.

Read the per-backend reference for CLI behavior, tested flags, and caveats:
`references/gemini-cli.md`, `references/opencode-cli.md`, `references/claude-cli.md`,
`references/codex-cli.md`, `references/pi-cli.md`.
