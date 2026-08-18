#!/usr/bin/env bats
# A body is sent only when one is supplied, and always with a JSON content type.

load ../test_helper

@test "POST sends the body verbatim" {
  run "$SCRIPT" POST /hosted-calendars '{"name":"Work","timezone":"Europe/Prague"}'
  [ "$status" -eq 0 ]
  [ "$(curl_body)" = '{"name":"Work","timezone":"Europe/Prague"}' ]
}

@test "POST with a body sets Content-Type: application/json" {
  run "$SCRIPT" POST /hosted-calendars '{"name":"Work"}'
  [ "$status" -eq 0 ]
  [ "$(curl_header "Content-Type:")" = "Content-Type: application/json" ]
}

@test "PATCH sends the body verbatim" {
  run "$SCRIPT" PATCH /events/evt-1 '{"title":"Renamed"}'
  [ "$status" -eq 0 ]
  [ "$(curl_body)" = '{"title":"Renamed"}' ]
}

@test "a body containing quotes and unicode survives intact" {
  run "$SCRIPT" POST /hosted-calendars '{"name":"Ann’s \"Work\" — cal"}'
  [ "$status" -eq 0 ]
  [ "$(curl_body)" = '{"name":"Ann’s \"Work\" — cal"}' ]
}

@test "a bodyless POST sends neither -d nor Content-Type" {
  run "$SCRIPT" POST '/calendars/{hosted:abc}/events/evt-1/cancel'
  [ "$status" -eq 0 ]
  [ -z "$(curl_body)" ]
  [ -z "$(curl_header "Content-Type:")" ]
}

@test "GET sends no body" {
  run "$SCRIPT" GET /hosted-calendars
  [ "$status" -eq 0 ]
  [ -z "$(curl_body)" ]
}

# curl turns -d without -X into a POST, so a body on a read would create the very
# resource the caller meant to list.
@test "GET with a body is refused, not silently sent as POST" {
  run "$SCRIPT" GET /sync-rules '{"name":"x"}'
  [ "$status" -eq 1 ]
  [[ "$output" == *"takes no request body"* ]]
}

@test "DELETE with a body is refused" {
  run "$SCRIPT" DELETE /events/evt-1 '{"force":true}'
  [ "$status" -eq 1 ]
  [[ "$output" == *"takes no request body"* ]]
}
