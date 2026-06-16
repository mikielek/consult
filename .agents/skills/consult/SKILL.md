---
name: consult
description: Bring in another coding agent as an independent second opinion. Use when the user explicitly asks to ask, consult, cross-check, debate with, or get a second opinion from another agent/model, including named backends such as Gemini, OpenCode, Claude, Codex, Pi, or an added backend. Also use for clearly high-risk independent review where another model is materially needed for safety, security, architecture, or regression risk. Do not trigger for ordinary review, debugging, or brainstorming unless external-agent help is requested. Treat responses as advice and verify claims locally before acting.
license: Apache-2.0
metadata:
  version: 1.0.0
---

# Consult

## Overview

Bring an external coding agent into the current task as an independent reviewer or design partner
when the user asks for that outside perspective. Treat any response as **advice**: verify
repo-specific claims yourself before changing code or reporting conclusions.

## Pick a backend

The user usually names one ("ask Gemini", "cross-check with OpenCode"). If they ask for an
unspecified outside opinion, list what is installed and ask which to use, or pick the only installed
backend:

```bash
<skill-dir>/scripts/consult.sh --list
```

`<skill-dir>` is this skill's base directory, for example `.agents/skills/consult` in this repo.
`--list` shows available adapters and whether their CLIs are on `PATH`. "Installed" does not imply
authenticated; the CLIs reuse the user's existing auth and need network access.

## Trust boundary

When reviewing an untrusted repository, do not execute that repository's project-local
`.agents/skills/consult/scripts/consult.sh`. A repo can change its local wrapper or adapters.
Use a trusted personal/global install by absolute path instead, for example
`~/.agents/skills/consult/scripts/consult.sh`. If the host environment provides
`CONSULT_TRUSTED_PATH`, prefer that absolute path over a repo-local wrapper.

## Run a consultation

Keep your shell at the **project root** so the backend sees the repo being discussed. Invoke the
dispatcher by its full path under the skill:

```bash
<skill-dir>/scripts/consult.sh --to gemini --prompt "<your consultation>"
```

Preview the exact backend command without executing (useful to confirm or to show the user):

```bash
<skill-dir>/scripts/consult.sh --to gemini --dry-run --prompt "<your consultation>"
```

Request machine-readable output only when the response will be parsed or logged; shapes are
backend-specific, and Pi intentionally rejects consult `--json`:

```bash
<skill-dir>/scripts/consult.sh --to opencode --json --prompt "Return a JSON object with a risks array."
```

The prompt may be passed with `--prompt` or as one positional argument. Use `--prompt` when the text
starts with `-`. Use `--from`, `--model`, `--file` (backend permitting), or `--raw` only when needed.
There is no `--`/passthrough; only documented normalized flags are accepted. See
`<skill-dir>/scripts/consult.sh --help`.

The wrapper scans the prompt text for a small set of obvious secret patterns before running or
printing a backend command. It aborts on a match unless `--allow-secrets` is supplied. This preflight
does not scan files passed with `--file`, repository contents the backend can read, or any data a
backend loads itself.

## What to ask for

Give enough context for the backend to answer independently, and ask for a concrete deliverable.
The dispatcher wraps your prompt with neutral advisory reviewer framing; you supply the substance:

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

- Default to a one-shot prompt for a single review, quick check, or standalone answer.
- Use one persistent session only when the user asks for continuity, debate, multiple rounds,
  iterative design, or follow-up memory on the same topic.
- Continue a session with `--resume latest` (only when no unrelated session intervened) or
  `--resume <session-id>`. Gemini and Claude also accept `--session-id <uuid>`; Pi accepts
  `--session-id <id>` for an exact project session id. OpenCode and Codex assign their own ids
  (capture them from output to resume).
- Note a persistent session id in your working notes when later rounds will need it. If the task
  changes materially, start a new session or ask whether to continue.

## Permissions and safety

> **Agent directive:** The consult wrapper is strictly non-interactive. Do not advise the user to
> focus the terminal, press tab, or provide input to a running consult command.

Consultations use mutation-restricted defaults; the strength varies by backend: **Codex** is
OS-sandbox-enforced read-only, **Gemini, OpenCode, and Claude** are approval/plan-gated
(effectively read-only headless, not a hard sandbox), and **Pi** is tool-allowlist and
discovery-hardened (not an OS sandbox). Per-backend safety mechanisms are detailed in
`references/<backend>-cli.md`.

Safety is also structural: the adapters accept only the documented normalized flags (no `--`
passthrough), so callers can't inject permission- or capability-shaping flags, and commands are
built as argv arrays with no shell eval.

All backends can still read accessible project files and return their contents. Mutation-restricted
does not mean secrecy-preserving. Avoid sending secrets or unnecessary proprietary data to a
third-party agent; summarize sensitive context or ask the user first. The prompt secret preflight is
a last-resort guard for obvious pasted credentials, not a general data-loss prevention mechanism.

If your host sandboxes network or auth, run the wrapper outside that sandbox — the CLIs reuse the
user's existing auth and need network access. **OpenAI Codex** users: see
`references/codex-permissions.md` for escalated-execution and prefix-approval guidance.

## Using results

- Extract the concrete claims, risks, or suggested checks.
- Verify them with local file reads, tests, or commands.
- Incorporate only the parts that survive verification.
- If host output is truncated, rerun with a tighter requested deliverable or use the backend's
  documented recovery/export path when one exists.
- Mention the consultation in your final answer when it materially influenced the result.

Read the per-backend reference for CLI behavior, tested flags, and caveats:
`references/gemini-cli.md`, `references/opencode-cli.md`, `references/claude-cli.md`,
`references/codex-cli.md`, `references/pi-cli.md`.
