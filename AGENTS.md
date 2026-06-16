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

There are no build artifacts, compiled assets, or formal test directories.

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

## Coding Style & Naming Conventions

Shell scripts use Bash with `set -euo pipefail`, argv arrays for command construction, and quoted
expansions. Keep adapters named after their backend, for example `gemini.sh` or `pi.sh`. Prefer
small backend-specific adapters over branching in `consult.sh`.

## Testing Guidelines

There is no automated test framework yet. For changes, run shell syntax checks and at least one
`--dry-run` for every backend you touch. For behavior claims in `references/*.md`, verify against
the actual CLI where practical and include version/date notes.

## Maintenance Hints

To add or remove a backend adapter, see
`.agents/skills/consult/references/backend-adapters.md`.

Backend tools change: CLI flags, exposed capabilities, auth flows, output formats, and session
behavior can drift. When modifying an adapter, check the current CLI help and verify what is
possible, especially where a tool previously fell short.

Important tradeoffs are not always obvious from the scripts. Preserve comparison notes,
shortcomings, and capability matrices in `references/*.md` so future maintainers can understand why
one backend uses a sandbox, another uses plan/approval mode, and Pi uses tool allowlists plus
discovery hardening.

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
