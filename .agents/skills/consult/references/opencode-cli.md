# OpenCode CLI Notes

Used by the `opencode` backend adapter (`scripts/backends/opencode.sh`).
Observed in a workspace on 2026-06-12; rechecked on 2026-06-18 with OpenCode `1.17.5`.
Also checked official OpenCode docs dated 2026-06-11.

## Relevant Official Docs

- CLI docs: https://opencode.ai/docs/cli/
- Agents docs: https://opencode.ai/docs/agents/
- Permissions docs: https://opencode.ai/docs/permissions/

## Help Output Highlights

`opencode --help` reports:

- `opencode [project]` starts the TUI by default.
- `opencode run [message..]` runs OpenCode non-interactively with a message (passed positionally).
- Top-level and `run` flags include `--model`, `--continue`, `--session`, `--fork`, and `--agent`.
- `opencode run` supports `--format default|json`, `--file`, `--title`, `--attach`, `--dir`,
  `--variant`, `--thinking`, and `--dangerously-skip-permissions`.
- `opencode session list` lists sessions, and `opencode export [sessionID]` exports session data.

Adapter mapping: `--resume latest` → `--continue`; `--resume <id>` → `--session <id>`;
`--json` → `--format json`; the prompt is passed positionally last. Consult does not expose
OpenCode file attachment flags; mention file paths directly in the prompt instead.

## Model discovery

- `opencode providers list` reports configured credentials. On 2026-06-18, it listed OpenAI (oauth),
  Google (oauth), and OpenCode Zen (api).
- `opencode models` lists provider-prefixed candidate model ids. On 2026-06-18, it listed 91 total:
  `openai`: 8, `google-vertex`: 31, `google-vertex-anthropic`: 7, `opencode`: 45.
- These are non-mutating diagnostics that use OpenCode's own configured credentials; they do not read
  private credential files directly.
- Probe via the wrapper using an exact id from `opencode models`:
  `scripts/consult.sh --to opencode --model <id> --prompt "hi"`. For example,
  `google-vertex-anthropic/claude-sonnet-4-6@default` is listed, while omitting `@default` fails
  before invocation with a model-not-found suggestion.
- Listing is not reachability proof. Probes succeeded for `openai/gpt-5.4-mini` and
  `google-vertex/gemini-2.5-flash`, while `opencode/gemini-3-flash` failed for missing billing,
  `openai/gpt-5.5-pro` failed for ChatGPT-account tier support, and
  `google-vertex-anthropic/claude-sonnet-4-6@default` failed for Vertex project access.

## Plan Agent and Permissions

OpenCode has a built-in `plan` primary agent for planning and analysis without direct
implementation. By default its file edits and bash commands are set to `ask`, not `deny` — so treat
it as **approval-gated** (effectively read-only in headless mode, where prompts can't be answered),
not a hard sandbox guarantee.

Permission actions: `allow` (run without approval), `ask` (prompt), `deny` (block).

Use `opencode run --agent plan` for consultation by default (the adapter does this), keep the prompt
explicitly read-only, and never pass `--dangerously-skip-permissions` (the adapter rejects it).

For strict read-only behavior, configure an OpenCode agent whose permissions deny `edit` and risky
`bash`. The consult adapter always uses `--agent plan` and supports no passthrough, so selecting a
different agent means editing `scripts/backends/opencode.sh` (or invoking `opencode` directly) —
not a consult flag.

## Testing Without Provider Auth

The dry-run path needs no auth and prints the resolved command:

```bash
scripts/consult.sh --to opencode --dry-run --prompt "..."
```

Running an actual consultation may require provider auth, network access, and approval handling
outside a restricted agent sandbox.
