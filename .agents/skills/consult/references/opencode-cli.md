# OpenCode CLI Notes

Used by the `opencode` backend adapter (`scripts/backends/opencode.sh`).
Observed in a workspace on 2026-06-12; rechecked on 2026-06-18 with OpenCode `1.17.5`, and on
2026-08-30 with OpenCode `1.18.25`.
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
  `--port`, `--username`/`--password`, `--variant`, `--thinking`, and `--auto` (in `1.17.5` the
  bypass flag was named `--dangerously-skip-permissions`).
- `opencode session list` lists sessions, and `opencode export [sessionID]` exports session data.

Adapter mapping: `--resume latest` → `--continue` (with a stderr warning); `--resume <id>` → `--session <id>`;
a fresh run gets `--title consult-<epoch>-<pid>-<random>` (see Session ids);
`--json` → `--format json`; the prompt is passed positionally last. Consult does not expose
OpenCode file attachment flags; mention in-tree file paths directly in the prompt instead.

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
explicitly read-only, and never pass the permission-bypass flag (`--auto` in `1.18.25`,
`--dangerously-skip-permissions` in `1.17.5`); the adapter has no passthrough, so it rejects both.

For strict read-only behavior, configure an OpenCode agent whose permissions deny `edit` and risky
`bash`. The consult adapter always uses `--agent plan` and supports no passthrough, so selecting a
different agent means editing `scripts/backends/opencode.sh` (or invoking `opencode` directly) —
not a consult flag.

## Read scope

Snapshot, not a contract — it turns on the CLI version, the agent/permission defaults, local
config, and the host sandbox, so re-measure rather than trusting this line.

On 2026-09-09 with OpenCode `1.18.15`, an out-of-tree absolute path was **refused**: reading
`/tmp/consult-reach/probe.txt` raised `permission requested: external_directory
(/tmp/consult-reach/*)`, which is **auto-rejected** headless (`The user rejected permission to use
this specific tool call.`), while an in-tree `README.md` read succeeded as the control. So an
out-of-tree path fails as a *permission* rejection, not as "file not found".

Either way, `SKILL.md` requires callers to name only in-tree paths, so nothing in the skill's
behavior depends on this result. Recipe: `backend-adapters.md` → "Re-measuring read scope".

## Session ids

opencode assigns its own ids and cannot create a session with a caller-chosen one (checked
2026-09-24, `1.18.32`: `run --session <unused id>` fails with `Session not found`). `--continue`
resumes the newest session of the project, so `--resume latest` silently crosses concurrent
callers. The adapter therefore reports the id of a fresh run:

- It passes `--title consult-<epoch>-<pid>-<random>`; after the run it reads
  `opencode session list --pure --format json` (rows carry `id`, `title`, `directory`, `projectId`,
  `created`, `updated`) and prints `consult-session: <id>` on stderr for the row with that exact title.
  A custom title is kept: opencode only auto-renames sessions still titled `New session - <date>`.
  Cost: consult sessions show up as `consult-…` in the TUI.
- It matches on title alone, not `directory`, which is redundant and breaks under symlinks,
  subdirectories and worktrees. Without `jq`, or if the lookup fails or matches nothing, the line
  reads `consult-session: unknown` and the exit status is untouched.
- Rejected alternatives: `--format json` (its event stream carries the id but turns stdout into JSONL)
  and a per-caller `XDG_DATA_HOME` (splits auth and config).
- `--resume <id>` prints `consult-session: <id>` before running; `--resume latest` prints a warning and
  no id line, since the continued session's id is not resolvable without a title.
- Only fresh runs leave `exec` (`run_capture_status` in `common.sh`); resumed runs still `exec`.
  Interrupting a fresh run: the first INT/TERM/HUP forwards TERM and suppresses the id line; a second
  escalates to KILL, which cannot free a hung grandchild (see `backend-adapters.md`). Terminal
  Ctrl-C also reaches opencode directly (shared process group).

## Reviewing Consult Sessions

Consult runs are not observable while they run: on `1.18.25`, plain `opencode run` opened no TCP
listener (`--port` bound nothing), and its session emitted no events on a separate server's stream.

They are fully reviewable afterwards, with no consult change. Sessions are stored in
`~/.local/share/opencode/opencode.db` (SQLite, not per-session files) and scoped by **project**
(`projectId`; one project can span several directories, and `session list` shows all of them), so
from the repo:

```bash
opencode session list            # ids + titles for this directory's project
opencode export <sessionID>      # full transcript as JSON (--sanitize redacts sensitive data)
```

Or start `opencode serve --port 4096` / `opencode web` / the TUI and browse the same sessions.

**Option, not implemented:** to watch a consult *live*, the adapter would have to pass
`--attach <url> --dir "$PWD"` so the run happens on an already-running server; the session then
streams on `/api/event` (the unprefixed `/event` does not carry session events). Caveats if this is
ever revisited: `--dir` is mandatory or the consult reads the server's directory instead of the
caller's; there is no fallback when the server is down, and OpenCode's error for that is a
misleading `Session not found`; and a shared server's config and plugins, not consult's flags,
would govern plan-agent behavior.

## Testing Without Provider Auth

The dry-run path needs no auth and prints the resolved command:

```bash
scripts/consult.sh --to opencode --dry-run --prompt "..."
```

Running an actual consultation may require provider auth, network access, and approval handling
outside a restricted agent sandbox.
