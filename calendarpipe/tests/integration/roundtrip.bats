#!/usr/bin/env bats
# Integration tests — hit the real CalendarPipe API. Need $CALENDARPIPE_API_KEY
# on a Pro plan (sync-rule endpoints answer 402 on free) and jq.
#
# Self-cleaning: throwaway calendar → exercise → delete, via an exit trap so a
# failure still cleans up. Events are dated 2099 so a leaked one can never
# surface in anybody's real calendar view. Nothing here sends email.

load ../test_helper

# The helper mocks curl by default so a stray unit test can never reach the
# network with a real key. These tests want the opposite.
setup() { :; }
teardown() { :; }

require_token() {
  if [ -z "${CALENDARPIPE_API_KEY:-}" ]; then
    skip "CALENDARPIPE_API_KEY not set"
  fi
}

json_field() {
  jq -r --arg f "$1" '(.data // .) | .[$f] // empty'
}

# ---------------------------------------------------------------------------

@test "listing calendars with a real key returns a JSON envelope" {
  require_token
  run "$SCRIPT" GET /calendars
  [ "$status" -eq 0 ]
  [[ "$output" == "{"* || "$output" == "["* ]]
}

@test "a bogus key is rejected with 401" {
  CALENDARPIPE_API_KEY="definitely-not-a-real-token-xxx" run "$SCRIPT" GET /calendars
  [ "$status" -eq 1 ]
  [[ "$output" == *"API key"* ]]
}

@test "full roundtrip: create calendar → create event → list → delete both" {
  require_token

  local cal_name="bats-test-$(date +%s)-$$"
  local cal_uuid=""
  local event_id=""

  cleanup() {
    [ -n "$event_id" ] && "$SCRIPT" DELETE "/events/${event_id}" >/dev/null 2>&1 || true
    [ -n "$cal_uuid" ] && "$SCRIPT" DELETE "/hosted-calendars/${cal_uuid}" >/dev/null 2>&1 || true
  }
  trap cleanup EXIT

  run "$SCRIPT" POST /hosted-calendars "{\"name\":\"${cal_name}\"}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$cal_name"* ]]
  cal_uuid=$(printf '%s' "$output" | json_field id)
  [ -n "$cal_uuid" ]

  # Far-future so a throwaway event can never collide with real calendar use.
  local event_title="bats-evt-$(date +%s)"
  run "$SCRIPT" POST "/calendars/{hosted:${cal_uuid}}/events" \
    "{\"title\":\"${event_title}\",\"start\":{\"dateTime\":\"2099-12-31T10:00:00Z\",\"timeZone\":\"UTC\"},\"end\":{\"dateTime\":\"2099-12-31T10:30:00Z\",\"timeZone\":\"UTC\"}}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$event_title"* ]]
  event_id=$(printf '%s' "$output" | json_field id)
  [ -n "$event_id" ]

  run "$SCRIPT" GET "/calendars/{hosted:${cal_uuid}}/events?start=2099-01-01T00:00:00Z&end=2100-01-01T00:00:00Z"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$event_title"* ]]

  run "$SCRIPT" DELETE "/events/${event_id}"
  [ "$status" -eq 0 ]
  event_id=""

  run "$SCRIPT" DELETE "/hosted-calendars/${cal_uuid}"
  [ "$status" -eq 0 ]
  cal_uuid=""
}

@test "sync-rule dry run executes a gate without persisting anything" {
  require_token

  local cal_name="bats-dryrun-$(date +%s)-$$"
  local cal_uuid=""

  cleanup() {
    [ -n "$cal_uuid" ] && "$SCRIPT" DELETE "/hosted-calendars/${cal_uuid}" >/dev/null 2>&1 || true
  }
  trap cleanup EXIT

  run "$SCRIPT" POST /hosted-calendars "{\"name\":\"${cal_name}\"}"
  [ "$status" -eq 0 ]
  cal_uuid=$(printf '%s' "$output" | json_field id)
  [ -n "$cal_uuid" ]

  run "$SCRIPT" POST /sync-rules/dry-run \
    "{\"code\":\"function gate(event) { return { pass: true, transform: { title: 'Busy' } }; }\",\"source\":\"hosted:${cal_uuid}\",\"limit\":3}"
  [ "$status" -eq 0 ]
  # A brand-new calendar has no events, so this must report the sample fallback
  # rather than silently claiming a clean run against real data.
  [[ "$output" == *"sample"* ]]

  run "$SCRIPT" GET /sync-rules
  [ "$status" -eq 0 ]
  [[ "$output" != *"$cal_name"* ]]

  run "$SCRIPT" DELETE "/hosted-calendars/${cal_uuid}"
  [ "$status" -eq 0 ]
  cal_uuid=""
}
