#!/usr/bin/env bats
# Query strings are the caller's to compose; braces work there too, so values
# containing ':' or ',' can be encoded without encoding the separators.

load ../test_helper

@test "passes a query string through unchanged" {
  run "$SCRIPT" GET '/calendars/{hosted:abc}/events?limit=100&start=2026-03-01T00:00:00Z'
  [ "$status" -eq 0 ]
  [[ "$(curl_url)" == *"?limit=100&start=2026-03-01T00:00:00Z" ]]
}

@test "encodes a braced query value without touching = or &" {
  run "$SCRIPT" GET '/events?calendarIds={hosted:a,hosted:b}&limit=50'
  [ "$status" -eq 0 ]
  [[ "$(curl_url)" == *"calendarIds=hosted%3Aa%2Chosted%3Ab&limit=50" ]]
}

@test "honours CALENDARPIPE_BASE_URL for local development" {
  CALENDARPIPE_BASE_URL="http://localhost:3000" run "$SCRIPT" GET /hosted-calendars
  [ "$status" -eq 0 ]
  [ "$(curl_url)" = "http://localhost:3000/api/v1/hosted-calendars" ]
}
