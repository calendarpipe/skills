#!/usr/bin/env bats
# The method reaches curl verbatim, and GET is sent without an -X flag.

load ../test_helper

@test "GET passes no -X flag" {
  run "$SCRIPT" GET /hosted-calendars
  [ "$status" -eq 0 ]
  [ "$(curl_method)" = "GET" ]
  [[ "$(curl_log)" != *"-X"* ]]
}

@test "every non-GET method reaches curl as -X <method>" {
  for method in POST PATCH PUT; do
    run "$SCRIPT" "$method" /hosted-calendars '{}'
    [ "$status" -eq 0 ]
    [ "$(curl_method)" = "$method" ]
  done

  run "$SCRIPT" DELETE /events/evt-1
  [ "$status" -eq 0 ]
  [ "$(curl_method)" = "DELETE" ]
}

@test "lowercase methods are accepted" {
  run "$SCRIPT" post /hosted-calendars '{}'
  [ "$status" -eq 0 ]
  [ "$(curl_method)" = "POST" ]
}

@test "an unsupported method is rejected before any request" {
  run "$SCRIPT" FETCH /hosted-calendars
  [ "$status" -eq 1 ]
  [[ "$output" == *"unsupported method"* ]]
}
