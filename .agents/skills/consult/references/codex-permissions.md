# Host-Specific Permissions (OpenAI Codex)

This file is **host-specific** and optional. The portable `SKILL.md` body stays neutral; read this
only when the consuming agent is **OpenAI Codex**, whose sandbox/approval model needs extra care.
Other agents (Claude Code, Gemini CLI, Cursor, …) can ignore this file.

## Why consultations skip the sandbox

Consultation CLIs (Gemini, OpenCode, …) reuse the user's existing CLI auth and need network access.
Inside Codex's restricted sandbox, headless prompts can block on browser auth or network prompts
that are not usefully interactive, and may leave stale processes. Run the wrapper with **escalated
execution from the start**; do not first try it sandboxed and fall back. The prompt stays read-only
even though the shell command runs outside the sandbox.

## Narrow, persistent prefix approval

Approve the wrapper itself, not a broad `gemini` / `opencode` / `bash` prefix, so future read-only
consultations run without repeated prompts:

```json
{
  "cmd": ".agents/skills/consult/scripts/consult.sh --to gemini --prompt \"...\"",
  "workdir": "<project-root>",
  "sandbox_permissions": "require_escalated",
  "prefix_rule": [".agents/skills/consult/scripts/consult.sh"],
  "justification": "Allow read-only consultations to use existing CLI auth outside the Codex sandbox?"
}
```

The canonical path is `.agents/skills/consult`; if Codex invokes the skill through a
`.codex/skills/consult` symlink instead, use that path in `cmd`/`prefix_rule` so the rule matches.

If that prefix approval is already saved, reuse the same escalated invocation; do not downgrade to a
sandboxed run. Run the wrapper directly from the project root so the prefix rule stays narrow and
predictable. Do not request a broad prefix such as `["gemini"]`, `["opencode"]`, `["bash"]`, or
`["python3"]`.

## Read-only scoping is still enforced

Escalated execution only lifts the *shell* sandbox. The consultation itself remains read-only:
the `gemini` adapter uses `--approval-mode plan`, the `opencode` adapter uses `--agent plan` and
rejects `--dangerously-skip-permissions`. Keep prompts advisory and avoid sending secrets.
