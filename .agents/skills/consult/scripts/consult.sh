#!/usr/bin/env bash
set -euo pipefail

# consult.sh - route an advisory consultation to a pluggable backend agent.
#
# Add a backend by dropping scripts/backends/<name>.sh; remove it by deleting
# the file. `consult.sh --list` discovers whatever is present.

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKENDS_DIR="$SKILL_DIR/scripts/backends"

usage() {
  cat <<'USAGE'
Usage:
  consult.sh --to BACKEND [--prompt TEXT | TEXT] [options]
  consult.sh --list
  consult.sh --help

Routes an advisory consultation to BACKEND (see --list) with mutation-restricted
defaults. Only the documented flags below are accepted — there is no '--'
passthrough to the backend CLI.

Normalized options (a backend may not support all of them):
  --to BACKEND        Which backend to consult. See --list.
  -p, --prompt TEXT   The consultation prompt. One positional TEXT argument is
                      also accepted; use --prompt if TEXT begins with '-'.
      --from CALLER   Name of the calling agent (default: "a coding agent").
      --json          Ask the backend for machine-readable output.
  -r, --resume VALUE  Continue a prior session ("latest" or a session id).
      --session-id ID Start a session with an explicit id (backend permitting).
  -m, --model MODEL   Use a specific model.
  -f, --file PATH     Attach a file (backend permitting; may repeat).
      --raw           Send --prompt verbatim, skipping the reviewer framing.
      --dry-run       Print the resolved backend command without running it.
  -h, --help          Show this help.

Notes:
  --json output is backend-specific: Codex emits JSONL events, Gemini/Claude/
  OpenCode use their CLI formats, and Pi rejects consult --json.
  Backend output is printed directly and may be truncated by the host UI.
  Exit 2 indicates wrapper validation or setup failure; live backend exits pass
  through otherwise.
USAGE
}

# Lists each backend with whether its CLI is installed (on PATH). The required
# binary is read from the adapter's `# consult-cli: <bin>` header (non-fatal if
# absent). "installed" means on PATH only — not that the CLI is authenticated.
list_backends() {
  shopt -s nullglob
  local f name bin status found=0
  for f in "$BACKENDS_DIR"/*.sh; do
    name="$(basename "${f%.sh}")"
    bin="$(sed -n 's/^# consult-cli:[[:space:]]*//p' "$f" | head -n1)"
    if [[ -z "$bin" ]]; then
      status="(CLI not declared)"
    elif command -v "$bin" >/dev/null 2>&1; then
      status="$bin: installed"
    else
      status="$bin: NOT INSTALLED"
    fi
    printf '%-10s %s\n' "$name" "$status"
    found=1
  done
  [[ "$found" -eq 1 ]] || echo "(no backends installed in $BACKENDS_DIR)" >&2
}

to=""
forward=()
forwarding=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --to)
      [[ $# -ge 2 ]] || { echo "missing value for --to" >&2; exit 2; }
      to="$2"
      shift 2
      ;;
    --to=*)
      to="${1#*=}"
      shift
      ;;
    --list)
      if [[ "$forwarding" -eq 0 ]]; then
        list_backends
        exit 0
      fi
      forward+=("$1")
      shift
      ;;
    -h|--help)
      if [[ "$forwarding" -eq 0 ]]; then
        usage
        exit 0
      fi
      forward+=("$1")
      shift
      ;;
    -p|--prompt|--from|-r|--resume|--session-id|-m|--model|-f|--file)
      forwarding=1
      if [[ $# -ge 2 ]]; then
        forward+=("$1" "$2")
        shift 2
      else
        forward+=("$1")
        shift
      fi
      ;;
    --json|--raw|--dry-run)
      forwarding=1
      forward+=("$1")
      shift
      ;;
    *)
      forwarding=1
      forward+=("$1")
      shift
      ;;
  esac
done

if [[ -z "$to" ]]; then
  echo "consult: --to BACKEND is required (try --list)" >&2
  exit 2
fi

# Reject anything but a bare backend name so --to can't reach scripts outside
# backends/ (e.g. ../foo, a/b). A case glob avoids the [[ =~ ]] quoting footgun.
case "$to" in
  *[!A-Za-z0-9_-]*) echo "consult: invalid backend name '$to'" >&2; exit 2 ;;
esac

adapter="$BACKENDS_DIR/$to.sh"
if [[ ! -f "$adapter" ]]; then
  echo "consult: unknown backend '$to'. Available:" >&2
  list_backends >&2
  exit 2
fi

exec bash "$adapter" "${forward[@]+"${forward[@]}"}"
