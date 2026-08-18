#!/usr/bin/env bats
# A non-2xx must fail loudly but still surface the response body — the API puts
# validation detail in there, and an agent that only sees "HTTP 400" cannot fix
# its own request.

load ../test_helper

@test "a 2xx exits 0 and prints the body" {
  export MOCK_CURL_RESPONSE='{"data":[]}
200'
  run "$SCRIPT" GET /hosted-calendars
  [ "$status" -eq 0 ]
  [ "$output" = '{"data":[]}' ]
}

@test "a 400 exits non-zero and still prints the body" {
  export MOCK_CURL_RESPONSE='{"error":"Validation failed","details":["name required"]}
400'
  run "$SCRIPT" POST /hosted-calendars '{}'
  [ "$status" -eq 1 ]
  [[ "$output" == *"name required"* ]]
  [[ "$output" == *"HTTP 400"* ]]
}

@test "a 402 explains that upgrading is a human action" {
  export MOCK_CURL_RESPONSE='{"error":"Pro plan required"}
402'
  run "$SCRIPT" GET /sync-rules
  [ "$status" -eq 1 ]
  [[ "$output" == *"Pro plan required"* ]]
  [[ "$output" == *"human"* ]]
}

@test "a 401 names the credential rather than the status alone" {
  export MOCK_CURL_RESPONSE='{"error":"Unauthorized"}
401'
  run "$SCRIPT" GET /hosted-calendars
  [ "$status" -eq 1 ]
  [[ "$output" == *"API key"* ]]
}

@test "a 3xx fails and points at the base URL" {
  export MOCK_CURL_RESPONSE='<html>Moved</html>
308'
  run "$SCRIPT" GET /hosted-calendars
  [ "$status" -eq 1 ]
  [[ "$output" == *"CALENDARPIPE_BASE_URL"* ]]
}

@test "an empty 204 body exits 0 and prints nothing" {
  export MOCK_CURL_RESPONSE='
204'
  run "$SCRIPT" DELETE /events/evt-1
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a response with no status line fails loudly rather than reading as success" {
  export MOCK_CURL_RESPONSE='{"ok":true}'
  run "$SCRIPT" GET /hosted-calendars
  [ "$status" -eq 1 ]
  [[ "$output" == *"no status line"* ]]
}
