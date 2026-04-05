#!/usr/bin/env bats
# Composite calendar IDs must be URL-encoded. This is the highest-risk area —
# the `:` separator breaks URLs if not encoded.

load ../test_helper

setup() { setup_mock_curl; }
teardown() { teardown_mock_curl; }

@test "list-events URL-encodes colon in hosted: prefix" {
  run "$SCRIPT" list-events "$TOKEN" "hosted:abc123"
  [ "$status" -eq 0 ]
  [[ "$(curl_url)" == *"hosted%3Aabc123"* ]]
  [[ "$(curl_url)" != *"hosted:abc123"* ]]
}

@test "list-events URL-encodes colon AND slash in account:provider/sub composite IDs" {
  run "$SCRIPT" list-events "$TOKEN" "acc-uuid:provider/family"
  [ "$status" -eq 0 ]
  [[ "$(curl_url)" == *"acc-uuid%3Aprovider%2Ffamily"* ]]
}

@test "list-events leaves plain account UUID unchanged" {
  run "$SCRIPT" list-events "$TOKEN" "abc-def-123"
  [ "$status" -eq 0 ]
  [[ "$(curl_url)" == *"/calendars/abc-def-123/events"* ]]
}

@test "create-event encodes composite cal_id in POST URL" {
  run "$SCRIPT" create-event "$TOKEN" "hosted:xyz" '{"title":"X"}'
  [ "$status" -eq 0 ]
  [[ "$(curl_url)" == *"hosted%3Axyz"* ]]
}

@test "cancel-event auto-prefixes 'hosted:' and encodes the result" {
  run "$SCRIPT" cancel-event "$TOKEN" "abc-123" "evt-456"
  [ "$status" -eq 0 ]
  # hosted: is added by the script, then encoded
  [[ "$(curl_url)" == *"hosted%3Aabc-123"* ]]
  [[ "$(curl_url)" == *"/events/evt-456/cancel"* ]]
}

@test "resend-invite auto-prefixes 'hosted:' and encodes the result" {
  run "$SCRIPT" resend-invite "$TOKEN" "abc-123" "evt-456"
  [ "$status" -eq 0 ]
  [[ "$(curl_url)" == *"hosted%3Aabc-123"* ]]
  [[ "$(curl_url)" == *"/events/evt-456/invite"* ]]
}
