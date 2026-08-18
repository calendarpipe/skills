#!/usr/bin/env bats
# Every request must carry Authorization: Bearer <token>, and the token must be
# resolved from the environment or config — never passed as a script argument,
# where it would land in shell history and `ps` output.

load ../test_helper

assert_auth_header() {
  local got; got="$(curl_header "Authorization:")"
  [ "$got" = "Authorization: Bearer ${TOKEN}" ] \
    || { echo "expected 'Authorization: Bearer $TOKEN', got: '$got'"; return 1; }
}

@test "every method sends the Authorization header" {
  run "$SCRIPT" GET /hosted-calendars
  [ "$status" -eq 0 ]
  assert_auth_header

  run "$SCRIPT" POST /hosted-calendars '{"name":"Test"}'
  [ "$status" -eq 0 ]
  assert_auth_header

  run "$SCRIPT" DELETE /events/evt-1
  [ "$status" -eq 0 ]
  assert_auth_header
}

@test "falls back to api_token in config.json when env var is unset" {
  unset CALENDARPIPE_API_KEY
  write_config '{"api_token":"from-config","calendar_id":"","feed_token":""}'
  run "$SCRIPT" GET /hosted-calendars
  [ "$status" -eq 0 ]
  [ "$(curl_header "Authorization:")" = "Authorization: Bearer from-config" ]
}

@test "env var wins over config.json" {
  write_config '{"api_token":"from-config"}'
  run "$SCRIPT" GET /hosted-calendars
  [ "$status" -eq 0 ]
  assert_auth_header
}

@test "exits 2 with a pointer to both sources when no key is available" {
  unset CALENDARPIPE_API_KEY
  run "$SCRIPT" GET /hosted-calendars
  [ "$status" -eq 2 ]
  [[ "$output" == *"CALENDARPIPE_API_KEY"* ]]
  [[ "$output" == *"config.json"* ]]
}

@test "exits 2 when config.json exists but carries no api_token" {
  unset CALENDARPIPE_API_KEY
  write_config '{"calendar_id":"abc"}'
  run "$SCRIPT" GET /hosted-calendars
  [ "$status" -eq 2 ]
  [[ "$output" == *"no api_token"* ]]
}

# ---------------------------------------------------------------------------
# Migration off the pre-2.0 location. Prose in SKILL.md cannot be relied on for
# this: an agent that skips setup and calls the API directly must still not be
# told to mint a second key while the first sits in the skill directory.
# ---------------------------------------------------------------------------

@test "moves a legacy skill-dir config into place and uses it" {
  unset CALENDARPIPE_API_KEY
  write_legacy_config '{"api_token":"legacy-token"}'

  run "$SCRIPT" GET /hosted-calendars
  [ "$status" -eq 0 ]
  [ "$(curl_header "Authorization:")" = "Authorization: Bearer legacy-token" ]
  [[ "$output" == *"moved"* ]]
  [ ! -f "${PROJECT_ROOT}/config.json" ]
  [ -f "$(config_path)" ]
}

@test "migrated config is not world-readable" {
  unset CALENDARPIPE_API_KEY
  write_legacy_config '{"api_token":"legacy-token"}'
  run "$SCRIPT" GET /hosted-calendars
  [ "$status" -eq 0 ]
  [ "$(file_mode "$(config_path)")" = "600" ]
}

@test "a legacy config never clobbers an existing one" {
  unset CALENDARPIPE_API_KEY
  write_config '{"api_token":"current-token"}'
  write_legacy_config '{"api_token":"legacy-token"}'

  run "$SCRIPT" GET /hosted-calendars
  [ "$status" -eq 0 ]
  [ "$(curl_header "Authorization:")" = "Authorization: Bearer current-token" ]
  [ -f "${PROJECT_ROOT}/config.json" ]
}
