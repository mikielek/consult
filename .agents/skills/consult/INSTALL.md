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

Personal/global (all repos for that agent) — use absolute paths here:

```bash
ln -s "$PWD/.agents/skills/consult" ~/.claude/skills/consult
ln -s "$PWD/.agents/skills/consult" ~/.codex/skills/consult
```

## Notes

- **Executable bit**: `scripts/consult.sh` is executable and invokes backend adapters via `bash`, so
  adapters do not need the exec bit. If a `cp` drops the bit on `consult.sh`, either
  `chmod +x scripts/consult.sh` or invoke it as `bash scripts/consult.sh ...`.
- **Backend CLIs**: each backend needs its CLI installed and authenticated (`gemini`, `opencode`,
  `claude`, `codex`, `pi`). Add a backend by dropping `scripts/backends/<name>.sh`; remove one by
  deleting the file.
