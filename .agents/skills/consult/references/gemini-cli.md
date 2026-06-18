# Gemini CLI Notes

Used by the `gemini` backend adapter (`scripts/backends/gemini.sh`).
Observed in a workspace on 2026-06-12 with Gemini CLI `0.46.0`; rechecked on
2026-06-18 with Gemini CLI `0.47.0`.

## Help Output Highlights

`gemini --help` reports:

- `gemini [query..]` launches interactive mode by default.
- `-p, --prompt` runs non-interactive headless mode.
- `--approval-mode` accepts `default`, `auto_edit`, `yolo`, and `plan`.
- `--resume` accepts `latest` or an index number.
- `--session-id` starts a new session with a caller-provided UUID.
- `--list-sessions` lists project sessions.
- `--output-format` accepts `text`, `json`, and `stream-json`.
- `--sandbox` exists, but it may require Docker/Podman or a configured `GEMINI_SANDBOX` command.

## Model discovery

Gemini CLI has no native model listing command in `0.47.0`. `gemini --list-sessions` is a
non-mutating diagnostic that only confirms the CLI can read the local project session store — it is
**not** a provider-auth check. Model choice relies on known ids (e.g. `gemini-2.5-flash`,
`gemini-2.5-pro`) passed via `--model`, plus a probe.

Probing is the only way to verify that Google auth and generation work. Run a one-shot consult
through the wrapper, which applies `--approval-mode plan`, the reviewer framing, and the secret
preflight:

```bash
scripts/consult.sh --to gemini --model gemini-2.5-flash --prompt "hi"
```

Add `--dry-run` to see the exact resolved `gemini` command (it includes `--model` and the framed
prompt; the approval-gated shape is shown under "Tested Behavior" below). Do not hand-run a raw
`gemini` probe — use the wrapper so the safe defaults and preflight always apply.

## Tested Behavior

Plain headless prompt from the user's shell:

```bash
gemini -p "hi"
```

returned a normal Gemini greeting.

Inside a restricted agent sandbox, headless prompts tried to open browser authentication. Running
the same prompt outside the sandbox with the user's existing Gemini CLI auth worked.

Approval-gated consultation (what the adapter sends):

```bash
gemini -p "You are Gemini, consulting with ..." --approval-mode plan
```

`--approval-mode plan` is **approval-gated** (no edits without approval, which is unavailable in
headless mode → effectively read-only), not an OS sandbox guarantee.

Session persistence:

```bash
gemini -p "Remember marker X" --approval-mode plan --session-id 11111111-2222-4333-8444-555555555555
gemini -p "What marker did I ask you to remember?" --approval-mode plan --resume latest
```

confirmed `--resume latest` persisted context.

JSON output:

```bash
gemini -p "Reply with exactly: JSON_OUTPUT_OK" --approval-mode plan --output-format json
```

returned an object with `session_id`, `response`, and `stats`.

Sandbox caveat:

```text
GEMINI_SANDBOX is true but failed to determine command for sandbox; install docker or podman or specify command in GEMINI_SANDBOX
```

Prefer `--approval-mode plan` for read-only scoping. Do not rely on `--sandbox` unless the host has
Docker/Podman or `GEMINI_SANDBOX` configured.
