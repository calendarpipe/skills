#!/usr/bin/env bats
# Integration tests — hit the real CalendarPipe API.
# Requires .env with CALENDARPIPE_API_TOKEN set.
# Tests are self-cleaning: create throwaway calendar → exercise → delete.

load ../test_helper

setup_file() {
  ENV_FILE="${PROJECT_ROOT}/.env"
  if [ -f "$ENV_FILE" ]; then
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
  fi
}

require_token() {
  if [ -z "${CALENDARPIPE_API_TOKEN:-}" ]; then
    skip "CALENDARPIPE_API_TOKEN not set (copy .env.example to .env)"
  fi
}

# Extract a JSON field via python3 (already a script dependency)
json_field() {
  local field="$1"
  python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',d).get('$field',''))"
}

# ---------------------------------------------------------------------------

@test "list-calendars with real token returns JSON response" {
  require_token
  run "$SCRIPT" list-calendars "$CALENDARPIPE_API_TOKEN"
  [ "$status" -eq 0 ]
  [[ "$output" == "{"* || "$output" == "["* ]]
}

@test "bogus token is rejected by the API" {
  run "$SCRIPT" list-calendars "definitely-not-a-real-token-xxx"
  [ "$status" -eq 0 ]  # curl exits 0, error is in body
  # Server returns an error envelope — assert it isn't a valid data response
  [[ "$output" == *"error"* || "$output" == *"nauthorized"* || "$output" == *"401"* || "$output" == *"Invalid"* ]]
}

@test "full roundtrip: create calendar → create event → list → delete event → delete calendar" {
  require_token

  local cal_name="bats-test-$(date +%s)-$$"
  local cal_uuid=""
  local event_id=""

  # Cleanup hook — always runs, swallows errors
  cleanup() {
    [ -n "$event_id" ] && "$SCRIPT" delete-event "$CALENDARPIPE_API_TOKEN" "$event_id" >/dev/null 2>&1 || true
    [ -n "$cal_uuid" ] && "$SCRIPT" delete-calendar "$CALENDARPIPE_API_TOKEN" "$cal_uuid" >/dev/null 2>&1 || true
  }
  trap cleanup EXIT

  # 1. Create throwaway hosted calendar
  run "$SCRIPT" create-calendar "$CALENDARPIPE_API_TOKEN" "$cal_name"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$cal_name"* ]]
  cal_uuid=$(printf '%s' "$output" | json_field id)
  [ -n "$cal_uuid" ]

  # 2. Create an event inside it (far-future so it can't collide with real use)
  local event_title="bats-evt-$(date +%s)"
  local body
  body=$(cat <<EOF
{"title":"$event_title","start":{"dateTime":"2099-12-31T10:00:00Z","timeZone":"UTC"},"end":{"dateTime":"2099-12-31T10:30:00Z","timeZone":"UTC"}}
EOF
)
  run "$SCRIPT" create-event "$CALENDARPIPE_API_TOKEN" "hosted:$cal_uuid" "$body"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$event_title"* ]]
  event_id=$(printf '%s' "$output" | json_field id)
  [ -n "$event_id" ]

  # 3. List events — the event we just created should be there
  run "$SCRIPT" list-events "$CALENDARPIPE_API_TOKEN" "hosted:$cal_uuid" "2099-01-01T00:00:00Z" "2100-01-01T00:00:00Z"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$event_title"* ]]

  # 4. Delete event explicitly
  run "$SCRIPT" delete-event "$CALENDARPIPE_API_TOKEN" "$event_id"
  [ "$status" -eq 0 ]
  event_id=""  # don't re-delete in cleanup

  # 5. Delete calendar explicitly
  run "$SCRIPT" delete-calendar "$CALENDARPIPE_API_TOKEN" "$cal_uuid"
  [ "$status" -eq 0 ]
  cal_uuid=""  # don't re-delete in cleanup
}
