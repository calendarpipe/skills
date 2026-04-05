#!/usr/bin/env bats
# Every command must send Authorization: Bearer <token>.

load ../test_helper

setup() { setup_mock_curl; }
teardown() { teardown_mock_curl; }

assert_auth_header() {
  local got; got="$(curl_header "Authorization:")"
  [ "$got" = "Authorization: Bearer ${TOKEN}" ] \
    || { echo "expected 'Authorization: Bearer $TOKEN', got: '$got'"; return 1; }
}

@test "list-events sends Authorization header" {
  run "$SCRIPT" list-events "$TOKEN" "hosted:abc"
  [ "$status" -eq 0 ]
  assert_auth_header
}

@test "list-all-events sends Authorization header" {
  run "$SCRIPT" list-all-events "$TOKEN"
  [ "$status" -eq 0 ]
  assert_auth_header
}

@test "create-event sends Authorization header" {
  run "$SCRIPT" create-event "$TOKEN" "hosted:abc" '{}'
  [ "$status" -eq 0 ]
  assert_auth_header
}

@test "update-event sends Authorization header" {
  run "$SCRIPT" update-event "$TOKEN" "evt-1" '{}'
  [ "$status" -eq 0 ]
  assert_auth_header
}

@test "delete-event sends Authorization header" {
  run "$SCRIPT" delete-event "$TOKEN" "evt-1"
  [ "$status" -eq 0 ]
  assert_auth_header
}

@test "cancel-event sends Authorization header" {
  run "$SCRIPT" cancel-event "$TOKEN" "abc" "evt-1"
  [ "$status" -eq 0 ]
  assert_auth_header
}

@test "list-invitations sends Authorization header" {
  run "$SCRIPT" list-invitations "$TOKEN" "cal-1"
  [ "$status" -eq 0 ]
  assert_auth_header
}

@test "respond sends Authorization header" {
  run "$SCRIPT" respond "$TOKEN" "cal-1" "uid-1" "ACCEPTED"
  [ "$status" -eq 0 ]
  assert_auth_header
}

@test "list-calendars sends Authorization header" {
  run "$SCRIPT" list-calendars "$TOKEN"
  [ "$status" -eq 0 ]
  assert_auth_header
}

@test "list-all-calendars sends Authorization header" {
  run "$SCRIPT" list-all-calendars "$TOKEN"
  [ "$status" -eq 0 ]
  assert_auth_header
}

@test "create-calendar sends Authorization header" {
  run "$SCRIPT" create-calendar "$TOKEN" "Test"
  [ "$status" -eq 0 ]
  assert_auth_header
}

@test "delete-calendar sends Authorization header" {
  run "$SCRIPT" delete-calendar "$TOKEN" "cal-uuid-1"
  [ "$status" -eq 0 ]
  assert_auth_header
}

@test "resend-invite sends Authorization header" {
  run "$SCRIPT" resend-invite "$TOKEN" "abc" "evt-1"
  [ "$status" -eq 0 ]
  assert_auth_header
}
