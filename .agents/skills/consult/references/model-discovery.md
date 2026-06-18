# Model discovery for consult (manual runbook)

**Status: manual on-demand workflow — not a `consult.sh` flag.** The host agent runs the
non-mutating diagnostic commands below directly when it needs to know what a backend can run; this
is not part of a normal consultation. "Probing" a model is a normal one-shot consult through the
wrapper. A scripted `--discover`/`--probe` mode is intentionally deferred (see Deferred below).

## The gap

`consult.sh --list` only checks whether a backend binary is on `PATH`. It does not confirm the CLI
is authenticated, nor which models the account can actually run. Discovery fills that gap on demand.

## Three layers

| Layer | Question | How |
|---|---|---|
| 1 — binary | Is the CLI installed? | `consult.sh --list` (`command -v`) |
| 2 — auth | Does the CLI have working credentials? | backend auth-signal command (see Parity) |
| 3 — candidates | Which model ids can it advertise? | backend listing command, if any (see Parity) |
| probe | Will a specific model actually respond? | one-shot consult: `consult.sh --to X --model Y --prompt "hi"` |

A model appearing in a listing does **not** guarantee it runs: billing (402/403), account tier
(400), missing project entitlement (404), or quota (429) surface only at invocation. Layer 3 is
candidate-gathering; only a probe verifies reachability.

## Safety invariant

These are **non-mutating diagnostics**: they don't change the repo, but a CLI may use its own
auth/config/session store or network (e.g. Pi takes a config lock; `gemini --list-sessions` is local
session-store liveness, not provider auth). The agent must **never hand-inspect credential or config
files** (`~/.codex/auth.json`, `~/.anthropic/`, `.claude/`, session logs, …) to discover or pick a
model — use only the documented CLI subcommands, which reach auth through the CLI's normal
mechanisms. This mirrors `SKILL.md` ("Model discovery is candidate-gathering, not routing").

## Probing (the only reachability check)

Probe a specific model by running a trivial one-shot consult and reading success/failure:

```bash
consult.sh --to X --model Y --prompt "hi"
```

Routing through the wrapper reuses the adapter's mutation-restricted defaults, argv discipline, and
secret preflight — so always probe this way rather than hand-rolling a vendor command.

- The **live** one-shot is the probe. `consult.sh --to X --model Y --dry-run --prompt "hi"` only
  *previews* the resolved command (and runs the secret preflight); it never contacts the provider,
  so it does not verify reachability.
- A probe costs one inference call (latency, quota, money) and confirms only that generation works —
  not task fitness. Probe the default or the specific model you intend to use; don't sweep whole
  catalogs.

## Where the commands live

The exact, volatile per-backend commands (auth signal, candidate listing, observed behavior) live in
each `references/<backend>-cli.md` "Model discovery" section. This file keeps only the cross-backend
view below.

## Backend parity

The strongest claim a non-probe check can honestly make differs per backend. A successful probe is
the only `verified-reachable` state. (This table is the file's only per-backend content — adding or
removing a backend is a one-row edit here; see `backend-adapters.md`.)

| Backend | Auth-signal command | Candidate source | Capability metadata | Strongest non-probe claim |
|---|---|---|---|---|
| opencode | `opencode providers list` | `opencode models [provider]` (provider-prefixed ids; some need suffixes like `@default`) | No | Authenticated-provider candidate listing |
| pi | `pi --list-models` (empty when unconfigured) | `pi --list-models [search]` | Yes (table) | Configured-provider rich candidate listing |
| codex | `codex doctor` (auth mode) | `codex debug models [--bundled]` | Yes (JSON) | Native raw catalog, not entitlement-checked |
| claude | `claude whoami` | none native | No | Authenticated account, no model listing |
| gemini | none explicit (`--list-sessions` = local liveness) | none native | No | Binary/session liveness, not provider auth |

Discovery levels (stable labels for reporting):

| Level | Meaning |
|---|---|
| `binary-only` | Installed; auth and models unknown (`consult.sh --list`) |
| `auth-signal` | CLI reports credentials/account state (`claude whoami`, `codex doctor`) |
| `local-liveness` | CLI reads local state but provider auth unproven (`gemini --list-sessions`) |
| `native-catalog` | CLI lists candidates, not entitlement (`codex debug models`) |
| `authenticated-listing` | CLI lists candidates scoped to configured providers (`opencode models`, `pi --list-models`) |
| `verified-reachable` | A minimal probe succeeded |

## Reporting findings

Summarize for the user as notes (this is a reporting template, not program output):

```
<backend>: <binary path | not found>; auth: <signal or unknown>;
  candidates: <source + count | no native listing>; caveat: listed != verified (probe to confirm).
```

## Worked example (snapshot, 2026-06-18)

Run in this repo; CLIs: opencode 1.17.5, Claude Code 2.1.181, Codex 0.141.0, Gemini 0.47.0, Pi
0.79.6. Illustrative provenance only — model availability drifts, so re-check rather than trust these
counts.

| Backend | Auth | Models listed | Probe (default/representative) |
|---|---|---|---|
| opencode | OpenAI, Google, OpenCode Zen | 91 provider-prefixed ids | mixed: `gpt-5.4-mini` OK, `gemini-2.5-flash` OK; `gpt-5.5-pro` fail (tier), `claude-…@default` fail (project), `opencode/gemini-3-flash` fail (billing) |
| pi | provider config present | 48 rich entries | default OK |
| codex | chatgpt | 4 raw (6 bundled) | default `gpt-5.5` OK |
| claude | anthropic account | no native listing | `claude-sonnet-4-6` OK |
| gemini | no explicit command | no native listing | default OK |

Takeaways: (1) listing != reachability — at least 3 of 91 opencode ids failed at runtime for
billing/tier/project reasons; (2) the same model has different ids per backend (`claude-sonnet-4-6`
vs `opencode/claude-sonnet-4-6` vs `google-vertex-anthropic/claude-sonnet-4-6@default`); (3) only
opencode/pi/codex expose any native listing — claude/gemini rely on known ids plus a probe.

## Deferred: scripted `--discover`

A scripted `consult.sh --discover [--to BACKEND]` (and opt-in `--probe`) is intentionally **not**
built. The manual runbook covers the on-demand diagnostic need, and a script that parsed
`opencode models` / `codex debug models` / `pi --list-models` would be brittle: those CLIs drift in
flags and output format (see `AGENTS.md`), so it would need pinned tests and constant upkeep, and it
would flatten each backend's native richness.

Build it only when a concrete machine-readable consumer (router, UI, cache) needs deterministic
normalized output. It would require: a top-level `--discover` mode in `consult.sh`; a per-adapter
mode guard (today all adapters run `parse_common_args → require_prompt → run_or_print` at source
time, so they would need a `main()`/discovery branch before `require_prompt`); a generic fallback and
output renderer in `common.sh`; and discovery cases in `tests/wrapper.sh`. There is intentionally
**no** `discover_models()` adapter hook today — do not assume one exists. Also deferred until then:
response caching/TTL, canonical model-id mapping across backends, cross-backend capability filters,
and maintained `known-models-<backend>.md` catalogs.

## Caveats

- **Auth signals are not reachability.** Layer 2 confirms a provider is listed or an auth command
  succeeds; it does not catch expired tokens, exhausted credits, quota, or per-model entitlements.
  Those surface only at probe time.
- **Capability metadata is uneven.** Pi's table and Codex's JSON expose context window / modalities;
  opencode's listing shows none. There is no cross-backend capability filter (deferred).
- **Model ids are not portable** across backends (see worked-example takeaway 2); use the exact id
  from that backend's listing, including required suffixes.
