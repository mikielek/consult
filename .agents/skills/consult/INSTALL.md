# Installing the `consult` skill across agents

This skill follows the **Agent Skills** open standard (`SKILL.md`), read by Claude Code, OpenAI
Codex, Gemini CLI, OpenCode, Cursor, Goose, Kiro, and others.

## Canonical source

The single source of truth lives in the vendor-neutral **`.agents/skills/consult`**. This is an
emerging cross-agent convention: some clients scan `.agents/skills/` directly (e.g. **Cursor 2.4**
and **Gemini CLI**, which gives it precedence over `.gemini/skills/`). Because every path inside
`SKILL.md` is **relative** (`scripts/consult.sh`, `scripts/backends/*.sh`, `references/*.md`), the
skill works unchanged from any location — copy or symlink both work.

## Make it visible to each agent

Not every agent scans `.agents/skills/` yet — Claude Code and Codex still primarily read their own
`.claude/skills/` and `.codex/skills/`. Symlink (or copy) the canonical dir into the agents you use.
Prefer **relative** symlinks so they stay valid if the repo moves and are safe to commit:

Project-scoped (per repo), run from the repo root:

```bash
ln -s ../../.agents/skills/consult .claude/skills/consult
ln -s ../../.agents/skills/consult .codex/skills/consult
ln -s ../../.agents/skills/consult .cursor/skills/consult
# Gemini CLI reads .agents/skills/ natively, so a .gemini/skills symlink is optional.

# …or copy (independent snapshot)
cp -r .agents/skills/consult .claude/skills/consult
```

Personal/global (all repos for that agent) — use absolute paths here.

**Recommended: a committed snapshot, hub plus spokes.** Install once into the vendor-neutral hub,
then point each agent's directory at the hub, so an update is one operation, not one per agent:

```bash
mkdir -p ~/.agents/skills/consult
git archive "HEAD:.agents/skills/consult" | tar -x -C ~/.agents/skills/consult
for d in ~/.claude/skills ~/.cursor/skills ~/.codex/skills; do
  ln -sfn ~/.agents/skills/consult "$d/consult"
done
```

`git archive "HEAD:..."` reads the **committed** tree, so an uncommitted or half-finished edit
cannot reach the install. That is the reason to prefer it over `cp -r` (which copies whatever is
lying in the working tree) or a symlink (which resolves there on every run).

Refresh after landing a change. Clear the directory first — `tar -x` overlays, so a plain re-extract
would leave behind a file deleted upstream, and a stale `scripts/backends/<name>.sh` keeps a removed
backend alive in `--list`:

```bash
rm -rf ~/.agents/skills/consult && mkdir -p ~/.agents/skills/consult
git archive "HEAD:.agents/skills/consult" | tar -x -C ~/.agents/skills/consult
git rev-parse HEAD > ~/.agents/skills/.consult-version   # keep the stamp outside the package
```

**Development only: symlink the working tree.** Edits go live with no refresh step, which is what
you want while changing the skill itself:

```bash
ln -sfn "$PWD/.agents/skills/consult" ~/.agents/skills/consult
```

Do not leave that in place for normal use. Every consult in every repo then runs whatever happens
to be in that working tree, so a branch switch, a rebase, or a half-written adapter silently changes
the skill everywhere — and the trusted-path guidance below stops meaning anything, because the
"trusted" absolute path resolves into a tree the repo controls.

## Security and trust boundaries

Project-scoped installs are convenient for trusted repositories, but do not execute
`.agents/skills/consult/scripts/consult.sh` from an untrusted checkout. The repository controls that
local script and its adapters.

For untrusted repository review, install `consult` once from a trusted source and invoke that copy by
absolute path while keeping the working directory at the repository being reviewed:

```bash
~/.agents/skills/consult/scripts/consult.sh --to gemini --prompt "Review this repository"
```

Autonomous agents can use an environment variable to make this preference explicit:

```bash
export CONSULT_TRUSTED_PATH="$HOME/.agents/skills/consult/scripts/consult.sh"
"$CONSULT_TRUSTED_PATH" --to gemini --prompt "Review this repository"
```

## Notes

- **Executable bit**: `scripts/consult.sh` is executable and invokes backend adapters via `bash`, so
  adapters do not need the exec bit. If a `cp` drops the bit on `consult.sh`, either
  `chmod +x scripts/consult.sh` or invoke it as `bash scripts/consult.sh ...`.
- **Which agents need a spoke**: Gemini CLI reads `~/.agents/skills/` natively (it reports a skill
  conflict when a project copy shadows the hub), so it needs no symlink. Pi has no skills
  *directory* — it takes `--skill <path>` — and the consult adapter passes `--no-skills`, so a
  consultation never loads skills either way; do not create `~/.pi/skills`.
- **Backend CLIs**: each backend needs its CLI installed and authenticated (`gemini`, `opencode`,
  `claude`, `codex`, `pi`). `consult.sh --list` only reports whether a CLI is on `PATH` — not whether
  it is authenticated or which models it can actually run; see `references/model-discovery.md` for the
  on-demand auth/model checks. Add a backend by dropping `scripts/backends/<name>.sh`; remove one by
  deleting the file. See `references/backend-adapters.md` for the full adapter-authoring guide.
