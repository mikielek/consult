# Antigravity CLI (agy) Notes

Used by the `agy` backend adapter (`scripts/backends/agy.sh`).
Observed in a workspace on 2026-10-05 with `agy 1.2.17` (Linux, signed in through the system
keyring; no settings.json permission rules).

## Fallback to gemini (host guidance)

`SKILL.md` routes Gemini requests that name no CLI to `--to agy` first. Switch to `--to gemini` only
for one of these failures, all of which happen before a usable session exists:

- agy is not on `PATH`, or cannot sign in or authenticate.
- An unknown or unavailable `--model`: exit 1 with `invalid model selection`, or exit 3 with an
  `AGY_ERROR` whose status is `NOT_FOUND`. A listed model can still be unavailable in the account's
  region. Ask the user before dropping or remapping the model. The ids differ between the two CLIs
  (`gemini-3.1-pro-high` is an agy id), so never pass an agy id to `gemini` unchecked.
- An empty answer whose stderr says `no output produced — a tool required the "…" permission`
  (see below). Retry agy once with a tighter prompt that names the exact in-tree files, then fall
  back.

Never fall back mid-session (sessions cannot move between backends), on a plan-mode refusal, or
because an answer is weak. The wrapper never falls back on its own. If both backends fail, report
both errors.

## Adapter invocation

```bash
agy --mode plan [--output-format json] [--model M] \
    [-c | --conversation ID | --log-file TMP] -p "PROMPT"
```

- `-p`/`--print`/`--prompt` takes the prompt as its **value**. Measured: `-p "--mode accept-edits"`
  arrived as a 19-character prompt, not as a flag, so a leading `-` is safe like `gemini -p`.
- A leading `/` is **not** safe: `agy --mode plan -p "/usage"` ran the `/usage` slash command and
  printed the quota table. The adapter therefore calls `guard_positional_prompt "Antigravity" "/"`
  for `--raw` prompts. Framed prompts never start with `/`.
- Do **not** add `--disable-slash-commands`. Combined with `--mode plan`, agy prints
  `warning: --mode plan has no effect while slash command expansion is disabled.` and runs in its
  default mode.
- `--mode` accepts `accept-edits` and `plan`. An unknown value only warns
  (`warning: unrecognized --mode value "bogus" (valid: accept-edits, plan)`) and the run continues
  in the default mode. That fails open, so the adapter refuses a live run unless `agy --help`
  (local, about 0.07 s) still lists `plan` under `--mode`. An unknown `--output-format` is accepted
  silently.
- `--print-timeout` defaults to unlimited, so a stuck turn holds the consult indefinitely. The
  wrapper sets no timeout.

## Headless permissions and the empty-answer trap

In print mode, agy **auto-denies** every tool that needs a permission prompt: `write_file`,
`command` (any shell command), and once `read_file` on an unusual path. The denial **ends the turn
with no answer**. Stdout is empty, the exit status is `0`, and stderr carries:

```text
jetski: no output produced — a tool required the "command" permission that headless mode cannot prompt for, so it was auto-denied. ...
```

With `--output-format json` the object has `"response": ""` and
`"denied_actions": [{"action":"command",...}]`. This is a safety property and also the main
reliability risk:

- Without steering, realistic reviews failed **0/9**: three in plan mode, three in default mode and
  two with `--sandbox` all tried a shell command first (`grep`, `head`). In plan mode agy also tries
  to write a plan artifact, which is denied in the same way.
- The adapter appends a "Headless note" to framed prompts that steers the model to its built-in
  file view/list/search tools. With it, reviews succeeded **6/6**: the same review 5 times (2 with plan
  mode effective, 3 without) plus an end-to-end review of `agy.sh` through the wrapper. Each took **4–6 minutes** (about 40k thinking tokens on the default model),
  against about 10–25 s for a short question.
- `--raw` prompts get no note and are far more likely to come back empty.
- `--sandbox` did not help. Commands were still permission-gated.

Callers should treat an empty answer plus a `no output produced` stderr line as a failed
consultation, not as "no findings".

## Safety

- Edits are blocked. Asked to create `agy-probe.txt` in-tree and in `/tmp`, agy produced no file in
  plan mode, in default mode, or with `--sandbox` (`write_file` auto-denied). Asked to run
  `touch … && git status`, nothing ran.
- This is **headless permission gating plus plan mode**, not an OS sandbox. It depends on local
  configuration: a `permissions.allow` rule in agy's settings, or `--dangerously-skip-permissions`
  (never emitted), would let tools run. With an empty `HOME`, plan mode wrote its plan and
  walkthrough artifacts into agy's own app-data `brain/` directory, outside the repo.
- agy loads `skills.json`, `rules.json`, `agents.json` and plugin manifests from every `.agents/`
  directory between the working directory and the project root (changelog 1.2.16), plus
  `.agents/skills/` folders. A repository under review can therefore shape the consultation, as
  with Qoder.

## Sessions

- `latest` maps to `-c`/`--continue`, and an id maps to `--conversation ID`. Verified: a marker
  stored in one run was recalled through `--conversation <id>`, also through the wrapper.
- There is no flag for a caller-chosen id, so consult `--session-id` is rejected.
- Text mode prints no id. A fresh run therefore gets a per-run `--log-file` (a `mktemp` file); the
  log records `Print mode: conversation=<uuid>` and, as measured, no prompt or response text. After
  the run the adapter prints `consult-session: <uuid>` (or `unknown`) on stderr and deletes the log.
  This runs through `run_capture_status`, as for opencode. Resumed runs `exec` directly.
- `--output-format json` returns one object: `conversation_id`, `status`, `response`,
  `duration_seconds`, `num_turns`, `usage`, and `denied_actions` when something was denied.

## Exit codes

| Situation | Exit | Notes |
|---|---|---|
| Success | 0 | |
| Tool denied, empty answer | 0 | See the empty-answer trap above |
| Unknown `--model` | 1 | `error: invalid model selection … not recognized`, followed by the available model names, before any session is created |
| Listed but unavailable model | 3 | Measured: `--model gemini-3.1-pro-high` (listed by `agy models`) gave `AGY_ERROR: {… "status":"NOT_FOUND","error_code":404 …}`, "Model `gemini-3.1-pro-preview` is not available in `eu` region", on stderr after a conversation was created |
| Other model or agent error mid-turn | 3 | `AGY_ERROR: {"short_error":…,"status":…,"retryable":…}` on stderr (changelog 1.2.10) |
| Missing auth | unmeasured | Credentials came from the keyring even with an empty `HOME` |

## Model discovery

`agy models` fetches the account's catalog (non-mutating). The ids look like
`gemini-3.8-flash-high` or `gemini-3.1-pro-low`: the effort level is part of the id, and the ids
differ from Gemini CLI's. Being listed does not mean a model is reachable: on 2026-10-05
`gemini-3.1-pro-high` was listed but failed with 404 "not available in `eu` region". Only a probe
verifies a model. A successful listing also shows that auth works. `agy -p "/usage"` shows
quota but is a slash command, so the wrapper cannot send it. Probe a model through the wrapper:

```bash
scripts/consult.sh --to agy --model gemini-3.1-pro-high --prompt "hi"
```

## Read scope

Snapshot, not a contract. Re-measure with the recipe in `backend-adapters.md`.

On 2026-10-05 with `agy 1.2.17`, the out-of-tree probe returned `REACH_MARKER_7Q` and the README
control returned `# Consult Skill`, so agy **reads outside the project tree**, at least for a
world-readable `/tmp` path.
