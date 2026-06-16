# Consult Skill

`consult` is an Agent Skills-compatible skill for asking another coding agent for an independent,
advisory consultation with mutation-restricted defaults: review, brainstorming pass, debugging
partner, or second opinion. A host agent can use it to involve installed backends including Gemini,
OpenCode, Claude, Codex, and Pi without making the user think about the underlying command wrapper.

The canonical skill lives at:

```text
.agents/skills/consult
```

See [`.agents/skills/consult/SKILL.md`](.agents/skills/consult/SKILL.md) for usage and safety
guidance, and [`.agents/skills/consult/INSTALL.md`](.agents/skills/consult/INSTALL.md) for agent
installation options.

## How To Use It

Ask your coding agent for the consultation you want in normal language:

```text
Ask Gemini to review this change critically and return only actionable risks.
```

```text
Consult Pi on the API design. Be thorough, but avoid overengineering.
```

```text
Have Gemini and Pi discuss this architecture for two rounds, then synthesize the tradeoffs.
```

```text
Ask OpenCode for debugging hypotheses and rank the next checks by expected signal.
```

The host agent handles backend selection, prompt framing, session continuity, and claim
verification. For multi-agent discussion, it can orchestrate rounds by consulting one backend,
feeding the result to another, and then summarizing what survived local verification.

## Direct Wrapper Usage

The shell wrapper is useful for maintainers, debugging, or manual use.

List available backends:

```bash
.agents/skills/consult/scripts/consult.sh --list
```

Run a consultation:

```bash
.agents/skills/consult/scripts/consult.sh --to gemini "Review this change for risks."
```

Use `--prompt` when it is clearer for scripts or when the prompt begins with `-`:

```bash
.agents/skills/consult/scripts/consult.sh --to gemini --prompt "Review this change for risks."
```

Preview the exact backend command:

```bash
.agents/skills/consult/scripts/consult.sh --to pi --dry-run "Check the API design."
```

Run deterministic wrapper checks:

```bash
.agents/skills/consult/tests/wrapper.sh
```

## Notes

- Backend CLIs must be installed and authenticated separately.
- Consultations are advisory; verify claims locally before acting on them.
- The strongest read-only guarantee is the Codex backend's OS sandbox. Other backends use
  approval, plan, or tool allowlist controls as documented in the skill references.
- `--json` output shape is backend-specific; Gemini, Claude, and OpenCode use their CLI formats,
  Codex emits JSONL events, and Pi intentionally rejects consult `--json`.
- The project is licensed under Apache-2.0. See `LICENSE` and `NOTICE`.
