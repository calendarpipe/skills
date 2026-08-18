#!/usr/bin/env bash
# CalendarPipe transport wrapper — auth, base URL, encoding, errors. Nothing else.
#
# It deliberately knows no endpoints: the operation list lives in
# references/endpoints.md, generated from the API's own OpenAPI spec. Adding an
# endpoint upstream must never require editing this file.

set -euo pipefail

# Percent-encoding is defined over bytes. Without this, bash walks a UTF-8 string
# by codepoint and `é` encodes as %E9 instead of %C3%A9, which the API rejects.
export LC_ALL=C

BASE_URL="${CALENDARPIPE_BASE_URL:-https://www.calendarpipe.com}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/calendarpipe"
CONFIG_FILE="${CONFIG_DIR}/config.json"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

print_help() {
  cat <<'EOF'
CalendarPipe transport wrapper

Usage:
  calendarpipe.sh <METHOD> <path> [json-body]

  METHOD    GET | POST | PATCH | PUT | DELETE
  path      Starts with '/'. The '/api/v1' prefix is added when absent.
  body      JSON string, for POST/PATCH/PUT.

Encoding:
  Anything inside {braces} is URL-encoded as a single path segment. Use it for
  every composite calendar ID — they contain ':' and Apple CalDAV IDs contain
  '/' as well, both of which corrupt the URL if passed raw.

Examples:
  calendarpipe.sh GET  /hosted-calendars
  calendarpipe.sh GET  '/calendars/{hosted:abc-123}/events?limit=100'
  calendarpipe.sh POST /sync-rules '{"name":"Work → Personal","source":"...","target":"..."}'
  calendarpipe.sh POST '/hosted-calendars/{cal-1}/invitations/{uid-1}/respond' '{"status":"ACCEPTED"}'

Authentication (first match wins):
  1. $CALENDARPIPE_API_KEY
  2. api_token in ~/.config/calendarpipe/config.json

Discovering endpoints:
  references/endpoints.md          — every operation, one line each
  curl -s "$BASE_URL/api/v1/openapi.json" | jq '.paths["<path>"]'
EOF
}

die() {
  echo "calendarpipe: $1" >&2
  exit "${2:-1}"
}

# Percent-encode every byte that is not an unreserved URL character.
urlencode() {
  local string="$1" out="" char code i
  for ((i = 0; i < ${#string}; i++)); do
    char="${string:i:1}"
    case "$char" in
      [a-zA-Z0-9.~_-]) out+="$char" ;;
      *)
        # Bytes above 0x7F arrive sign-extended; mask back to the raw octet.
        printf -v code '%d' "'$char"
        out+="$(printf '%%%02X' "$((code & 0xFF))")"
        ;;
    esac
  done
  printf '%s' "$out"
}

# Counting braces is not enough: `}a{b` balances but would encode nothing and
# duplicate the tail, so walk the string and reject anything but flat pairs.
validate_braces() {
  local raw="$1" char depth=0 i
  for ((i = 0; i < ${#raw}; i++)); do
    char="${raw:i:1}"
    case "$char" in
      "{")
        depth=$((depth + 1))
        [ "$depth" -le 1 ] || die "nested braces in path: $raw"
        ;;
      "}")
        depth=$((depth - 1))
        [ "$depth" -ge 0 ] || die "closing brace before opening brace in path: $raw"
        ;;
    esac
  done
  [ "$depth" -eq 0 ] || die "unbalanced braces in path: $raw"
}

# Encode each {braced} group, pass everything else through untouched.
encode_braced() {
  local raw="$1" out="" rest="$1" before inside
  validate_braces "$raw"

  while [[ "$rest" == *"{"* ]]; do
    before="${rest%%\{*}"
    rest="${rest#*\{}"
    inside="${rest%%\}*}"
    rest="${rest#*\}}"
    out+="${before}$(urlencode "$inside")"
  done
  printf '%s%s' "$out" "$rest"
}

# Config used to live in the skill directory, where `skills update` can destroy
# it. Runs on every invocation because the setup prose an agent may never read is
# the wrong place to move a live credential. Never clobbers a good config.
migrate_legacy_config() {
  local legacy="${SKILL_DIR}/config.json"
  [ -f "$legacy" ] || return 0

  if [ -f "$CONFIG_FILE" ]; then
    echo "calendarpipe: ignoring stale ${legacy}; ${CONFIG_FILE} already exists" >&2
    return 0
  fi

  mkdir -p "$CONFIG_DIR"
  mv "$legacy" "$CONFIG_FILE"
  chmod 600 "$CONFIG_FILE"
  echo "calendarpipe: moved ${legacy} to ${CONFIG_FILE}" >&2
}

if [ $# -eq 0 ]; then
  print_help
  exit 0
fi

case "$1" in
  help | --help | -h)
    print_help
    exit 0
    ;;
esac

[ $# -ge 2 ] || die "usage: calendarpipe.sh <METHOD> <path> [json-body]"

method="$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')"
path="$2"
body="${3:-}"

case "$method" in
  GET | POST | PATCH | PUT | DELETE) ;;
  *) die "unsupported method: $method" ;;
esac

# curl infers POST from -d when no -X is given, so a body on a GET would turn a
# read into a write. Refuse rather than silently sending something else.
if [ -n "${3:-}" ] && { [ "$method" = "GET" ] || [ "$method" = "DELETE" ]; }; then
  die "$method takes no request body"
fi

[[ "$path" == /* ]] || die "path must start with '/': $path"
[[ "$path" == /api/v1/* ]] || path="/api/v1${path}"

migrate_legacy_config

token="${CALENDARPIPE_API_KEY:-}"
if [ -z "$token" ]; then
  [ -f "$CONFIG_FILE" ] \
    || die "no API key. Set \$CALENDARPIPE_API_KEY or add api_token to ${CONFIG_FILE}" 2
  command -v jq >/dev/null 2>&1 \
    || die "jq is required to read ${CONFIG_FILE}. Install jq, or set \$CALENDARPIPE_API_KEY."
  token="$(jq -re '.api_token // empty' "$CONFIG_FILE" 2>/dev/null)" \
    || die "no api_token in ${CONFIG_FILE}. Set \$CALENDARPIPE_API_KEY or add one." 2
fi

url="${BASE_URL}$(encode_braced "$path")"

args=(-sS)
[ "$method" = "GET" ] || args+=(-X "$method")
# The token goes in argv of curl, never of this script — a key passed as a
# script argument lands in the caller's shell history and in `ps` output.
args+=(-H "Authorization: Bearer ${token}")
if [ -n "$body" ]; then
  args+=(-H "Content-Type: application/json" -d "$body")
fi
# Trailing status line, split back off below. Keep the URL last — the test
# harness reads it as the final argument.
args+=(-w $'\n%{http_code}')
args+=("$url")

response="$(curl "${args[@]}")"

# `set -e` aborts above if curl itself failed, so a zero exit always carries the
# `-w` status as the final line.
status="${response##*$'\n'}"
body_out="${response%$'\n'*}"
[[ "$status" =~ ^[0-9]{3}$ ]] || die "malformed response from curl: no status line"

# `[ -n "$x" ] && printf ...` would make an empty body (a 204) the script's exit
# status under `set -e`.
if [ -n "$body_out" ]; then
  printf '%s\n' "$body_out"
fi

if [ "$status" -lt 200 ] || [ "$status" -ge 300 ]; then
  case "$status" in
    3??) echo "calendarpipe: HTTP ${status} — unexpected redirect. Check \$CALENDARPIPE_BASE_URL." >&2 ;;
    401) echo "calendarpipe: 401 — API key missing or invalid." >&2 ;;
    402) echo "calendarpipe: 402 — Pro plan required. The human must upgrade in the dashboard." >&2 ;;
    404) echo "calendarpipe: 404 — not found, or not owned by this API key." >&2 ;;
    *) echo "calendarpipe: HTTP ${status}" >&2 ;;
  esac
  exit 1
fi

exit 0
