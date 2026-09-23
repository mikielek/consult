# Qoder CLI Notes

Used by the `qoder` backend adapter (`scripts/backends/qoder.sh`).
Observed in a workspace on 2026-09-23 with `qoder 1.1.62`.

## Adapter invocation

```bash
qoder -p --permission-mode plan [-o json] [--model M] \
      [-c | --resume ID] [--session-id ID] "PROMPT"
```

- `-p`/`--print` is a **boolean** flag (unlike `gemini -p PROMPT`); the prompt is positional and
  last. The usage line is `[query...]` — variadic — so every option must precede the prompt or it
  can be absorbed into the query.
- `--permission-mode plan` = read-only review. Verified blocking: asked to create a file it replied
  `REFUSED` and no file appeared, both for a path inside its own `-w` working directory and for an
  out-of-tree `/tmp` path. This is **approval/policy-gated** read-only, not an OS sandbox.
- `-o json` (`--output-format`) returns a **single JSON result object** (fields include `type`,
  `subtype`, `is_error`, `result`, `session_id`, `uuid`, `usage`), not a JSONL event stream.
  `stream-json` is the event-stream format and is not what consult `--json` selects.
- `--model` accepts a model name (`Default and New Models use model name; Custom uses modelID`).

**`--help` is wrong about the modes.** `qoder --help` lists `--permission-mode` choices as
`default, accept_edits, bypass_permissions, dont_ask, auto` and **omits `plan`**, but the parser
accepts and enforces it (an invalid value echoes the full choice set, including `plan`). Trust the
validation error over the help text when they disagree.

## Model discovery

`qoder whoami` prints the signed-in account (non-mutating, no session started); `qoder status` shows
session status. `qoder --list-models` is a real native listing, scoped to the current user's
available models, printing a `MODEL` header and one name per line — the strongest candidate source of
any consult backend, and the account scoping is the point: listed means *this account can use it*,
which still is not a reachability guarantee (billing, tier and quota surface only at probe time).

Probe a model by running a one-shot consult through the wrapper, which applies the adapter's plan
mode, reviewer framing, and secret preflight:

```bash
scripts/consult.sh --to qoder --model Qwen3.8-Max --prompt "hi"
```

Add `--dry-run` to see the exact resolved command. Do not hand-run a raw `qoder` probe — use the
wrapper so the safe defaults and preflight always apply.

## Read scope

Snapshot, not a contract — it turns on the CLI version, the agent/permission defaults, local config,
and the host sandbox, so re-measure rather than trusting this line.

On 2026-09-23 with `qoder 1.1.62`, an out-of-tree absolute path was **refused**:
`/tmp/consult-reach/probe.txt` returned `CANNOT_READ` while the in-tree `README.md` control returned
its heading, so the refusal is a workspace boundary rather than an auth or model failure. Qoder
therefore groups with Gemini (hard workspace boundary) rather than Claude and Pi (read out of tree
fine). `--permission-mode plan` gates mutation, and read reach is separately workspace-scoped.

Either way, `SKILL.md` requires callers to name only in-tree paths, so nothing in the skill's
behavior depends on this result. Recipe: `backend-adapters.md` → "Re-measuring read scope".

## Session persistence

- `--resume latest` → `-c` (`--continue`, most recent session).
- `--resume <id>` → `--resume <id>`. Verified: a codeword from an earlier turn was recalled.
- `--session-id <uuid>` alone is honored — the id passed in was echoed back as the result's
  `session_id`. It must look like a UUID.
- `--resume` and `--session-id` together are rejected by the CLI itself: `--session-id can only be
  used with --continue or --resume when --fork-session is also specified.` The adapter rejects the
  pair earlier with a consult-shaped message, so `--fork-session` (which would make the combination
  legal, by branching history) is deliberately unreachable from consult.
- Without either flag, a session is still persisted; pass `--no-session-persistence` to opt out (not
  currently wired into the normalized interface).
- With `-o json`, capture `session_id` from the result to resume a specific later consultation.

## Caveats

- **Self-consultation.** Qoder is frequently the *host* running consult, so `--to qoder` from a
  Qoder session spawns a second Qoder sharing the same account, model catalog and skill set. The
  sub-session gets a fresh context (an independent answer, not the same reasoning trace), but it is
  not an independent vendor. When genuine independence is the point, prefer another backend.
- **Project config is loaded.** The adapter isolates nothing: project- and local-scoped settings,
  hooks, plugins and MCP servers from the repository being consulted are read by default, so a
  repository that ships `.qoder/settings*.json` with hooks can run code during a consultation. Use a
  trusted-path wrapper install (see `SKILL.md` "Trust boundary") when reviewing untrusted code. The
  CLI's own `--setting-sources`, `--strict-mcp-config` and `--config-dir` flags would harden this and
  are not used here, by design, to stay consistent with the other plan/approval-gated adapters.
- **A skill-conflict notice appears on stderr** in this workspace
  (`Detected 1 skill name conflict across sources. Run /skills to inspect.`). It is stderr-only, so
  `-o json` stdout still parses cleanly — but do not treat its presence as a consult failure.
- Several capability-shaping flags exist but are deliberately unreachable (no `--` passthrough):
  `--permission-mode bypass_permissions`, `--dangerously-skip-permissions`, `--tools`,
  `--allowed-tools`, `--disallowed-tools`, `--add-dir`, `--attachment`, `--mcp-config`, `--agent`,
  `--system-prompt`, `--worktree`, `--remote`. The prompt is positional, so `common.sh` also rejects
  a `--raw` prompt beginning with `-`; without that guard, `--raw` would be a route into that same
  flag set.
- `-w/--cwd` would move the backend off the project root; consult relies on the caller's shell being
  at the project root instead.
