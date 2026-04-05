#!/usr/bin/env bats
# Each command must use the correct HTTP method.

load ../test_helper

setup() { setup_mock_curl; }
teardown() { teardown_mock_curl; }

# --- GET (no -X flag) ---

@test "list-events is GET" {
  run "$SCRIPT" list-events "$TOKEN" "hosted:abc"
  [ "$status" -eq 0 ]
  [ "$(curl_method)" = "GET" ]
}

@test "list-all-events is GET" {
  run "$SCRIPT" list-all-events "$TOKEN"
  [ "$status" -eq 0 ]
  [ "$(curl_method)" = "GET" ]
}

@test "list-invitations is GET" {
  run "$SCRIPT" list-invitations "$TOKEN" "cal-123"
  [ "$status" -eq 0 ]
  [ "$(curl_method)" = "GET" ]
}

@test "list-calendars is GET" {
  run "$SCRIPT" list-calendars "$TOKEN"
  [ "$status" -eq 0 ]
  [ "$(curl_method)" = "GET" ]
}

@test "list-all-calendars is GET" {
  run "$SCRIPT" list-all-calendars "$TOKEN"
  [ "$status" -eq 0 ]
  [ "$(curl_method)" = "GET" ]
}

# --- POST ---

@test "create-event is POST" {
  run "$SCRIPT" create-event "$TOKEN" "hosted:abc" '{}'
  [ "$status" -eq 0 ]
  [ "$(curl_method)" = "POST" ]
}

@test "create-calendar is POST" {
  run "$SCRIPT" create-calendar "$TOKEN" "Work"
  [ "$status" -eq 0 ]
  [ "$(curl_method)" = "POST" ]
}

@test "cancel-event is POST" {
  run "$SCRIPT" cancel-event "$TOKEN" "abc" "evt-1"
  [ "$status" -eq 0 ]
  [ "$(curl_method)" = "POST" ]
}

@test "respond is POST" {
  run "$SCRIPT" respond "$TOKEN" "cal-1" "uid-1" "ACCEPTED"
  [ "$status" -eq 0 ]
  [ "$(curl_method)" = "POST" ]
}

@test "resend-invite is POST" {
  run "$SCRIPT" resend-invite "$TOKEN" "abc" "evt-1"
  [ "$status" -eq 0 ]
  [ "$(curl_method)" = "POST" ]
}

# --- PATCH ---

@test "update-event is PATCH" {
  run "$SCRIPT" update-event "$TOKEN" "evt-1" '{"title":"New"}'
  [ "$status" -eq 0 ]
  [ "$(curl_method)" = "PATCH" ]
}

# --- DELETE ---

@test "delete-event is DELETE" {
  run "$SCRIPT" delete-event "$TOKEN" "evt-1"
  [ "$status" -eq 0 ]
  [ "$(curl_method)" = "DELETE" ]
}

@test "delete-calendar is DELETE" {
  run "$SCRIPT" delete-calendar "$TOKEN" "cal-uuid-1"
  [ "$status" -eq 0 ]
  [ "$(curl_method)" = "DELETE" ]
  [[ "$(curl_url)" == *"/api/v1/hosted-calendars/cal-uuid-1" ]]
}
