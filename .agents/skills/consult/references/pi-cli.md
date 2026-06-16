# Pi CLI Notes

Used by the `pi` backend adapter (`scripts/backends/pi.sh`).
Observed in a workspace on 2026-06-16 with Pi `0.79.4`
(`@earendil-works/pi-coding-agent`).

## Adapter invocation

```bash
pi -p --tools read,grep,ls --no-extensions --no-skills \
   --no-prompt-templates --no-themes --no-context-files --no-approve \
   [--model M] \
   [--continue | --session ID] [--session-id ID] [--no-session] \
   [@file...] "PROMPT"
```

`--no-session` is appended only when neither `--resume` nor `--session-id` is given (one-shot
calls); flag order is otherwise irrelevant to Pi's parser.

- `-p`/`--print` = non-interactive headless mode. The prompt is positional.
- `--tools read,grep,ls` is the adapter's read-only boundary. Pi has no built-in plan,
  approval, or sandbox mode, so the adapter allowlists only read-only built-in tools and excludes
  `edit`, `write`, `bash`, and interactive tools.
- `--no-extensions --no-skills --no-prompt-templates --no-themes --no-context-files --no-approve`
  disables discovered extension/custom tools, skills, templates, themes, context files, and
  project-local trust loading for the consult run.
- `--model` accepts model patterns or full provider-prefixed ids such as
  `anthropic/claude-...`; Pi's default provider is Google.
- The consult `--json` option is intentionally unsupported for Pi. Pi's `--mode json` emits verbose
  JSONL with intermediate tool/thinking events, while plain `pi -p` already filters that stream and
  prints only the final response. Omit `--json` for normal Pi consults.

## Session persistence

- `--resume latest` -> `--continue` (most recent session).
- `--resume <id>` -> `--session <id>` (specific session file or partial UUID).
- `--session-id <id>` -> `--session-id <id>` (exact project session id, created if missing).
- One-shot calls use `--no-session` when neither `--resume` nor `--session-id` is supplied, so
  prompt and attached file contents are not persisted in Pi's session store by default.
- The adapter deliberately avoids Pi's `--resume`/`-r` because it opens an interactive session
  picker, which is unsafe for headless consult runs.
- `--resume` and `--session-id` are mutually exclusive in the adapter.

## Files

Pi includes files with `@path` arguments, so the adapter maps each consult `--file PATH` to
`@PATH` and places those arguments before the prompt. Pi reads these paths locally while constructing
the initial message, outside the `--tools` allowlist. Any file readable by the Pi process can be
included this way, regardless of project boundaries.

## Read-only model

Pi's own docs describe read-only review with a tool allowlist such as
`pi --tools read,grep,find,ls -p "Review the code"`. The consult adapter intentionally uses
the narrower `read,grep,ls` allowlist plus discovery-disabling flags. This removes known mutation
paths, including shell access and discovered extension/custom tools (the `--tools` allowlist
applies across all tool sources, so any MCP-provided tools are excluded too), but it is not an OS sandbox:
Pi can still read any file visible to the process through `@path`, `read`, `grep`, or `ls` and
return its contents.

## Caveats

- Pi has no safe `--` end-of-options delimiter, and its argument parser scans all argv for flags
  and `@file` includes. The adapter rejects `--raw` prompts beginning with `-` or `@` so a raw
  prompt cannot be interpreted as a Pi flag, session picker, project-trust flag, or file include.
- A raw single-string prompt such as `"--tools bash"` is not a read-only bypass because Pi only
  honors `--tools` as its own argv token with a separate value.
- Pi attempts to acquire locks under its config directory, such as `settings.json.lock` and
  `trust.json.lock`, even for basic commands. It needs a writable Pi config directory and can fail
  before running in strict read-only sandboxes. In OpenAI Codex, run the wrapper with escalated
  execution as described in `references/codex-permissions.md`.
- The binary name is short. If an unrelated `pi` binary appears earlier on `PATH`, `--list` may
  report it as installed but runs will fail confusingly. Confirm `command -v pi` resolves to
  `@earendil-works/pi-coding-agent` when troubleshooting.
- Pi uses provider API keys from env by default (`--api-key` defaults to provider env vars).
  "Installed" only means the CLI is on `PATH`; it does not mean Pi is authenticated.
