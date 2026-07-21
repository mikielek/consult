# Host-Specific Permissions (OpenAI Codex)

This file is **host-specific**. When **OpenAI Codex** has a default/restricted sandbox, read it
before a live consultation so the wrapper runs with the capabilities its backend needs. Other
agents (Claude Code, Gemini CLI, Cursor, …) and explicitly unrestricted Codex hosts can ignore it.

## Choose execution from the active capabilities

Live consultation CLIs need network access and may read or write backend auth, config, session,
cache, or log state outside the project workspace. This applies to every live backend, not only
Claude, even though the exact failure mode differs by CLI.

| Operation | Active Codex capabilities | Execution |
|---|---|---|
| `consult.sh --list`, top-level `--help`, or any `--dry-run` | Any | Keep sandboxed |
| Live consultation or reachability probe | Default/restricted sandbox | Request escalated execution on the first attempt |
| Live consultation or reachability probe | Explicit network and required backend-state access | Run normally; do not request redundant escalation |

Treat normal read-only or workspace-write profiles as restricted unless the host explicitly grants
both command network access and access to the backend's required state paths. In a restricted
profile, do not run an auth check or live probe as a sandbox test and then fall back: it can hang,
prompt for unusable interactive authentication, fail on an external state path, or leave stale
processes. If escalation is denied or unavailable, report that the consultation cannot run under
the active sandbox and provide the wrapper command for the user to run outside it; do not retry or
loop inside the sandbox.

## Narrow, persistent prefix approval

Approve the wrapper itself, not a broad `gemini` / `opencode` / `bash` prefix, so future
mutation-restricted consultations run without repeated prompts:

```json
{
  "cmd": ".agents/skills/consult/scripts/consult.sh --to gemini --prompt \"...\"",
  "workdir": "<project-root>",
  "sandbox_permissions": "require_escalated",
  "prefix_rule": [".agents/skills/consult/scripts/consult.sh"],
  "justification": "Allow mutation-restricted consultations to use existing CLI auth outside the Codex sandbox?"
}
```

Use the exact trusted wrapper path in both `cmd` and `prefix_rule`: the repo-local
`.agents/skills/consult/scripts/consult.sh` path is appropriate only for a trusted repository. For
an untrusted repository, use the absolute `CONSULT_TRUSTED_PATH` or personal/global wrapper path
required by `SKILL.md`. If Codex invokes the skill through a `.codex/skills/consult` symlink, use
that path so the rule matches.

If that prefix approval is already saved, reuse the same escalated invocation; do not downgrade to a
sandboxed run. Run the wrapper directly from the project root so the prefix rule stays narrow and
predictable. Do not request a broad prefix such as `["gemini"]`, `["opencode"]`, `["bash"]`, or
`["python3"]`.

`sandbox_permissions`, the approval justification, and `prefix_rule` are Codex host metadata; they
are not wrapper flags and are not added to the backend prompt. The narrow persistent prefix avoids
repeated approval prompts without broadening approval to raw backend commands.

## Mutation restrictions still apply

Escalated execution only lifts the *shell* sandbox. The consultation still uses backend-specific
restrictions: the `codex` adapter passes `-s read-only -a never`, the `gemini` adapter uses
`--approval-mode plan`, the `claude` adapter uses `--permission-mode plan`, the `opencode` adapter
uses `--agent plan`, and the `pi` adapter uses a read-only tool allowlist with discovery disabled.
Keep prompts advisory and avoid sending secrets.
