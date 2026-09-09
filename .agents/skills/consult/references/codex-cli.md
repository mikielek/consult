# Codex CLI Notes

Used by the `codex` backend adapter (`scripts/backends/codex.sh`).
Observed in a workspace on 2026-06-16 with `codex-cli 0.140.0`; rechecked on
2026-06-18 with `codex-cli 0.141.0`.

## Adapter invocation

```bash
# fresh:
codex -s read-only -a never exec --skip-git-repo-check --color never [--json] [-m M] "PROMPT"
# resume:
codex -s read-only -a never exec resume (--last | ID) --skip-git-repo-check [--json] [-m M] "PROMPT"
```

- **Flag placement (important):** `-s/--sandbox` and `-a/--ask-for-approval` are **top-level** flags
  and must come *before* `exec`. Verified on 0.140.0: `codex exec -s read-only -a never …` →
  `error: unexpected argument '-a' found`, while `codex -s read-only -a never exec …` works. Top-level
  placement also applies to `exec resume`, so read-only is enforced on resume the same way (no config
  override needed).
- `-s read-only` = **OS-sandbox-enforced** read-only (the strongest guarantee among the backends).
  `-a never` = never pause for approval (non-interactive; failures are returned to the model).
- `--skip-git-repo-check` lets it run outside a git repo (accepted on both `exec` and `exec resume`).
- `--color never` keeps captured output clean; it is accepted on `exec` but **not** on `exec resume`,
  so the adapter omits it when resuming.
- `--model` → `-m`. The prompt is positional (last).

## JSON output

`--json` prints **JSONL** — newline-delimited JSON *events*, not a single JSON object (unlike
gemini's `--output-format json`). Consumers must read it line by line / as a stream.

## Model discovery

These are non-mutating diagnostics that use Codex's own auth/config; none reads private credential
files directly.

- `codex doctor` reports auth state, including stored auth mode (`chatgpt`, `api-key`, etc.).
- `codex debug models` renders the refreshed raw model catalog as JSON. On 2026-06-18, the current
  configured run listed `gpt-5.5`, `gpt-5.4`, `gpt-5.4-mini`, and hidden `codex-auto-review`.
- `codex debug models --bundled` skips refresh and dumps the catalog shipped with the binary. On
  0.141.0, this bundled catalog also included `gpt-5.3-codex` and `gpt-5.2`.
- Treat the catalog as candidate discovery, not account-specific reachability proof. A fresh
  `CODEX_HOME` without stored auth can still render a bundled/raw catalog; probe a model with a
  one-shot consult through the wrapper to verify actual generation:
  `scripts/consult.sh --to codex --model gpt-5.5 --prompt "hi"`.

## Read scope

Snapshot, not a contract — it turns on the CLI version, the agent/permission defaults, local
config, and the host sandbox, so re-measure rather than trusting this line.

**Not measured.** On 2026-09-09 the probe could not run on `codex-cli 0.147.0`: `Error: Your access
token could not be refreshed. Please log out and sign in again.` Re-run it after `codex login`.
Unlike the other backends, Codex is OS-sandbox-enforced (`-s read-only`) and the adapter passes no
`-C`/root configuration, so the answer may also depend on the sandbox's default read roots.

Either way, `SKILL.md` requires callers to name only in-tree paths, so nothing in the skill's
behavior depends on this result. Recipe: `backend-adapters.md` → "Re-measuring read scope".

## Session persistence

- `--resume latest` → `exec resume --last` (most recent recorded session).
- `--resume <id>` → `exec resume <id>` (UUID or thread name).
- Setting a custom session id is unsupported (Codex assigns its own), so the adapter rejects
  `--session-id`; capture the id from `--json` output if you need to resume a specific one.

## Caveats

- Web/search is left at the CLI default (the adapter does not pass `--search`, which is off by default).
