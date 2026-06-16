# Codex CLI Notes

Used by the `codex` backend adapter (`scripts/backends/codex.sh`).
Observed in a workspace on 2026-06-16 with `codex-cli 0.140.0`.

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

## Session persistence

- `--resume latest` → `exec resume --last` (most recent recorded session).
- `--resume <id>` → `exec resume <id>` (UUID or thread name).
- Setting a custom session id is unsupported (Codex assigns its own), so the adapter rejects
  `--session-id`; capture the id from `--json` output if you need to resume a specific one.

## Caveats

- Web/search is left at the CLI default (the adapter does not pass `--search`, which is off by default).
