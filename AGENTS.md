# Repository Guidelines

## Project Structure & Module Organization

This repository publishes the `consult` Agent Skill. The canonical skill package is
`.agents/skills/consult/`.

- `.agents/skills/consult/SKILL.md` is the main skill entrypoint and user-facing workflow.
- `.agents/skills/consult/INSTALL.md` documents installation and symlink options.
- `.agents/skills/consult/scripts/consult.sh` is the dispatcher.
- `.agents/skills/consult/scripts/backends/*.sh` are backend adapters.
- `.agents/skills/consult/scripts/lib/common.sh` contains shared argument parsing and prompt framing.
- `.agents/skills/consult/references/*.md` records backend-specific CLI behavior and caveats.
- `.agents/skills/consult/tests/wrapper.sh` is a dependency-free deterministic wrapper harness.
- `evals/evals.json` records trigger and output eval seed cases for host/model eval runners.

There are no build artifacts or compiled assets.

## Build, Test, and Development Commands

No build step is required. Useful local checks:

```bash
.agents/skills/consult/scripts/consult.sh --list
```

Lists available backend adapters and whether their CLIs are on `PATH`.

```bash
bash -n .agents/skills/consult/scripts/consult.sh
for f in .agents/skills/consult/scripts/backends/*.sh .agents/skills/consult/scripts/lib/common.sh; do bash -n "$f"; done
```

Checks shell syntax.

```bash
.agents/skills/consult/scripts/consult.sh --to pi --dry-run "Review this API"
```

Verifies generated backend commands without invoking a model.

```bash
.agents/skills/consult/tests/wrapper.sh
```

Runs deterministic wrapper checks with fake backend binaries; it should not call any model.

```bash
jq empty evals/evals.json
```

Validates that the eval corpus is well-formed JSON.

## Coding Style & Naming Conventions

Shell scripts use Bash with `set -euo pipefail`, argv arrays for command construction, and quoted
expansions. Keep adapters named after their backend, for example `gemini.sh` or `pi.sh`. Prefer
small backend-specific adapters over branching in `consult.sh`.

## Testing Guidelines

For changes, run shell syntax checks and `.agents/skills/consult/tests/wrapper.sh`. Also run at
least one `--dry-run` for every backend you touch. For behavior claims in `references/*.md`, verify
against the actual CLI where practical and include version/date notes. When a change alters trigger,
routing, or output-guidance semantics in `SKILL.md`, update `evals/evals.json` to match (or note why
no update is needed) and validate it with `jq empty evals/evals.json`.

## Maintenance Hints

To add or remove a backend adapter, see
`.agents/skills/consult/references/backend-adapters.md`.

**Fixing the `gemini-cli` Ripgrep warning:**
If you run `gemini` locally on Linux (especially with Linuxbrew or `~/.local/bin` binaries) and see
`Ripgrep is not available. Falling back to GrepTool.`, it is because `gemini-cli` only trusts strict
system paths (like `/usr/bin/rg`). To fix this without `sudo`, create a symlink to your local `rg`
within the gemini module:
```bash
mkdir -p ~/.config/nvm/versions/node/v24.15.0/lib/node_modules/@google/gemini-cli/bundle/vendor/ripgrep
ln -s ~/.local/bin/rg ~/.config/nvm/versions/node/v24.15.0/lib/node_modules/@google/gemini-cli/bundle/vendor/ripgrep/rg-linux-x64
```
*(Adjust the node path and `rg-linux-x64` to match your architecture and OS if necessary).*

Backend tools change: CLI flags, exposed capabilities, auth flows, output formats, and session
behavior can drift. When modifying an adapter, check the current CLI help and verify what is
possible, especially where a tool previously fell short.

Important tradeoffs are not always obvious from the scripts. Preserve comparison notes,
shortcomings, and capability matrices in `references/*.md` so future maintainers can understand why
one backend uses a sandbox, another uses plan/approval mode, and Pi uses tool allowlists plus
discovery hardening.

Retrospective notes from the trigger/safety tightening work:

- Keep the skill frontmatter trigger narrow. Explicit external-agent requests should trigger; plain
  "review this code", "debug this test", and "brainstorm options" should not trigger consult unless
  the user asks for another agent/model or a clearly high-risk independent review.
- The shared parser accepts exactly one non-flag positional prompt for convenience. Prompts beginning
  with `-` must use `--prompt`; there is no `--` passthrough by design.
- `consult.sh` has a small outer parser before adapter/common parsing. It may intercept top-level
  `--to`, `--list`, and `--help`, but once any backend-forwarded argument starts it must preserve
  later tokens verbatim, including values like `--prompt "--help"` or `--resume "--list"`. Keep
  regression coverage for this in `tests/wrapper.sh`.
- Be precise about safety wording. Only Codex has the strongest OS-sandbox read-only guarantee.
  Gemini, Claude, and OpenCode are plan/approval-gated, and Pi is tool-allowlist/discovery-hardened.
  All backends can still read accessible files and return their contents.
- `--resume` and `--session-id` conflicts live in adapters because backend support differs. Codex and
  OpenCode reject caller-provided session ids; Gemini, Claude, and Pi support them but not together
  with resume.
- `--file` was intentionally removed from the normalized consult interface. It was a leaky
  backend-specific abstraction: some adapters rejected it, OpenCode forwarded it, and Pi's old
  `@path` mapping read files while constructing the prompt outside the tool allowlist. Ask callers
  to mention paths in the prompt instead.
- Do not treat Canonical Change Review as a Pi-only workaround. Do not add Pi bash/git passthrough,
  direct `git show` allowlisting via shell, or `--file`/`--context-file` substitutes to solve
  change-review parity. The issue is consistent review input across backends with different
  permissions, sandboxes, current files, staged state, untracked files, and CLI behavior. The prompt
  secret preflight is intentionally narrow and never scans referenced files, so artifact files must
  be sanitized by the host.
- Pi consult `--json` is intentionally unsupported because Pi JSON mode emits verbose JSONL
  tool/thinking events while plain `pi -p` prints the final response. Do not re-add `--mode json`
  unless a caller is prepared to consume that event stream.
- Pi has no safe `--` end-of-options delimiter. The adapter rejects `--raw --prompt` values starting
  with `-` or `@`; test those exact forms because a positional `-...` prompt fails earlier in common
  parsing.
- The prompt secret preflight is intentionally narrow: scan only the normalized `PROMPT` payload,
  run before dry-run can print the backend command, and do not scan repository files.
  `--allow-secrets` is the explicit escape hatch.
- The consult wrapper is non-interactive by design. Do not document or suggest focusing a terminal,
  pressing tab, or entering input into a running consult command.
- Trusted-path guidance for untrusted repositories is documentation for callers and host agents, not
  a guarantee a repo-local script can enforce. Prefer a known absolute path such as
  `CONSULT_TRUSTED_PATH` when reviewing untrusted code.
- `evals/evals.json` is an artifact, not an executable harness. Keep deterministic wrapper behavior
  in `.agents/skills/consult/tests/wrapper.sh`; use the eval JSON for host/model trigger and output
  quality checks. Validate it with `jq empty evals/evals.json`, and update it whenever trigger,
  routing, or output-guidance semantics in `SKILL.md` change so the corpus does not silently drift
  from the skill contract. The `trigger_evals` are not deterministically runnable (classifying
  natural-language input needs a model judge), so do not add a behavioral runner or schema validator
  for them here.
- Prefer a documented manual workflow over a scripted feature when the skill's "user" is an LLM agent
  and the underlying CLIs drift or there is no machine-readable consumer yet. Example: model discovery
  is a manual runbook (`references/model-discovery.md`), not a `--discover` flag; "probing" a model is
  a one-shot consult through the wrapper (`--to X --model Y --prompt "hi"`), which reuses the adapter's
  safe defaults and secret preflight. The wrapper one-shot is the **only** recommended probe — keep
  raw vendor probe commands out of the docs and point to `--dry-run` for the exact resolved command
  (the live one-shot verifies reachability; `--dry-run` only previews it). There is intentionally no
  `discover_models()` adapter hook.
- `references/*.md` are on-demand runbooks loaded into the agent's context, so keep them concise and
  token-efficient. The **detailed, volatile command blocks** (flags, output details, version notes)
  live in `references/<backend>-cli.md`; cross-backend synthesis lives in
  `references/model-discovery.md`, whose Parity table may name minimal auth/listing commands for
  comparison but should not repeat the detailed blocks.
- Mind per-backend touchpoints when adding or removing a backend: besides the adapter, the discovery
  Parity table in `references/model-discovery.md` is one. The canonical add/remove checklist is in
  `references/backend-adapters.md`.

## Commit & Pull Request Guidelines

Author commits with the full name `Michał Kiełkowski` and no email address. The author and
committer fields use an empty email, which renders as `Michał Kiełkowski <>` in the log:

```bash
GIT_AUTHOR_NAME="Michał Kiełkowski" GIT_AUTHOR_EMAIL="" \
GIT_COMMITTER_NAME="Michał Kiełkowski" GIT_COMMITTER_EMAIL="" \
  git commit -m "Your subject"
```

Use concise, imperative commit subjects (for example `Initial commit` or `Add pi backend`), with an
optional body when the change needs explanation. Keep commits focused.

Pull requests should describe the backend or workflow affected, list validation commands run, and
call out any security or read-only behavior changes. Link issues when applicable.

## Security & Configuration Tips

Do not commit secrets, local session logs, or copied agent config directories. Keep `.agents/` as
the canonical source; `.claude/`, `.codex/`, `.cursor/`, and `.gemini/` are local mirrors or
symlinks and are ignored.
