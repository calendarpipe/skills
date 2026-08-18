#!/usr/bin/env bats
# The /api/v1 prefix is optional at the call site, so the paths in
# references/endpoints.md can be pasted either with or without it.

load ../test_helper

@test "prefixes /api/v1 when omitted" {
  run "$SCRIPT" GET /sync-rules
  [ "$status" -eq 0 ]
  [[ "$(curl_url)" == *"/api/v1/sync-rules" ]]
}

@test "does not double-prefix a path that already carries /api/v1" {
  run "$SCRIPT" GET /api/v1/sync-rules
  [ "$status" -eq 0 ]
  [[ "$(curl_url)" == *"/api/v1/sync-rules" ]]
  [[ "$(curl_url)" != *"/api/v1/api/v1/"* ]]
}

@test "rejects a path that does not start with a slash" {
  run "$SCRIPT" GET sync-rules
  [ "$status" -eq 1 ]
  [[ "$output" == *"must start with"* ]]
}

@test "requires both a method and a path" {
  run "$SCRIPT" GET
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage"* ]]
}
