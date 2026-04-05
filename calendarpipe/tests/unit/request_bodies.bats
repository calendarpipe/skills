#!/usr/bin/env bats
# JSON request bodies for write operations.

load ../test_helper

setup() { setup_mock_curl; }
teardown() { teardown_mock_curl; }

@test "create-event forwards event_json verbatim" {
  local body='{"title":"Standup","start":{"dateTime":"2026-03-25T10:00:00Z"}}'
  run "$SCRIPT" create-event "$TOKEN" "hosted:abc" "$body"
  [ "$status" -eq 0 ]
  [ "$(curl_body)" = "$body" ]
}

@test "update-event forwards update_json verbatim" {
  local body='{"title":"Renamed"}'
  run "$SCRIPT" update-event "$TOKEN" "evt-1" "$body"
  [ "$status" -eq 0 ]
  [ "$(curl_body)" = "$body" ]
}

@test "respond body is {\"status\": \"<value>\"}" {
  run "$SCRIPT" respond "$TOKEN" "cal-1" "uid-1" "ACCEPTED"
  [ "$status" -eq 0 ]
  [ "$(curl_body)" = '{"status": "ACCEPTED"}' ]
}

@test "respond DECLINED sets correct status in body" {
  run "$SCRIPT" respond "$TOKEN" "cal-1" "uid-1" "DECLINED"
  [ "$status" -eq 0 ]
  [ "$(curl_body)" = '{"status": "DECLINED"}' ]
}

@test "create-calendar name only uses default timezone UTC, no organizer key" {
  run "$SCRIPT" create-calendar "$TOKEN" "My Cal"
  [ "$status" -eq 0 ]
  local body; body="$(curl_body)"
  [[ "$body" == *'"name": "My Cal"'* ]]
  [[ "$body" == *'"timezone": "UTC"'* ]]
  [[ "$body" != *"organizerDisplayName"* ]]
}

@test "create-calendar with timezone overrides default" {
  run "$SCRIPT" create-calendar "$TOKEN" "My Cal" "America/New_York"
  [ "$status" -eq 0 ]
  [[ "$(curl_body)" == *'"timezone": "America/New_York"'* ]]
}

@test "create-calendar with organizer includes organizerDisplayName" {
  run "$SCRIPT" create-calendar "$TOKEN" "My Cal" "UTC" "Alice Smith"
  [ "$status" -eq 0 ]
  [[ "$(curl_body)" == *'"organizerDisplayName": "Alice Smith"'* ]]
}

@test "write operations send Content-Type: application/json" {
  run "$SCRIPT" create-event "$TOKEN" "hosted:abc" '{}'
  [ "$status" -eq 0 ]
  [[ "$(curl_header "Content-Type:")" == "Content-Type: application/json" ]]
}
