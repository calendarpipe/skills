#!/usr/bin/env bats
# Optional args must be appended as query params only when provided.

load ../test_helper

setup() { setup_mock_curl; }
teardown() { teardown_mock_curl; }

# --- list-events ---

@test "list-events without start/end has only limit param" {
  run "$SCRIPT" list-events "$TOKEN" "hosted:abc"
  [ "$status" -eq 0 ]
  local url; url="$(curl_url)"
  [[ "$url" == *"?limit=100"* ]]
  [[ "$url" != *"&start="* ]]
  [[ "$url" != *"&end="* ]]
}

@test "list-events with start+end appends both" {
  run "$SCRIPT" list-events "$TOKEN" "hosted:abc" "2026-01-01T00:00:00Z" "2026-01-31T23:59:59Z"
  [ "$status" -eq 0 ]
  local url; url="$(curl_url)"
  [[ "$url" == *"&start=2026-01-01T00:00:00Z"* ]]
  [[ "$url" == *"&end=2026-01-31T23:59:59Z"* ]]
}

@test "list-events with only start (no end) appends just start" {
  run "$SCRIPT" list-events "$TOKEN" "hosted:abc" "2026-01-01T00:00:00Z"
  [ "$status" -eq 0 ]
  local url; url="$(curl_url)"
  [[ "$url" == *"&start=2026-01-01T00:00:00Z"* ]]
  [[ "$url" != *"&end="* ]]
}

# --- list-all-events ---

@test "list-all-events with calendarIds URL-encodes comma-separated list" {
  run "$SCRIPT" list-all-events "$TOKEN" "" "" "hosted:abc,acc:prov/sub"
  [ "$status" -eq 0 ]
  local url; url="$(curl_url)"
  # comma → %2C, colon → %3A, slash → %2F
  [[ "$url" == *"calendarIds=hosted%3Aabc%2Cacc%3Aprov%2Fsub"* ]]
}

@test "list-all-events with no filters hits base events endpoint" {
  run "$SCRIPT" list-all-events "$TOKEN"
  [ "$status" -eq 0 ]
  local url; url="$(curl_url)"
  [[ "$url" == *"/api/v1/events?limit=100"* ]]
  [[ "$url" != *"&start="* ]]
  [[ "$url" != *"&end="* ]]
  [[ "$url" != *"&calendarIds="* ]]
}

# --- list-invitations ---

@test "list-invitations without status has no query string" {
  run "$SCRIPT" list-invitations "$TOKEN" "cal-123"
  [ "$status" -eq 0 ]
  local url; url="$(curl_url)"
  [[ "$url" == *"/hosted-calendars/cal-123/invitations" ]]
  [[ "$url" != *"?"* ]]
}

@test "list-invitations with status appends ?status=" {
  run "$SCRIPT" list-invitations "$TOKEN" "cal-123" "pending"
  [ "$status" -eq 0 ]
  [[ "$(curl_url)" == *"/invitations?status=pending" ]]
}
