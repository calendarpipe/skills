#!/usr/bin/env bats
# Help is what an agent reads before its first call, so it must show the call
# shape, the brace-encoding rule, and where the endpoint list lives.

load ../test_helper

@test "no arguments prints help and exits 0" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"<METHOD> <path>"* ]]
}

@test "help, --help and -h all work" {
  for flag in help --help -h; do
    run "$SCRIPT" "$flag"
    [ "$status" -eq 0 ]
    [[ "$output" == *"CalendarPipe transport wrapper"* ]]
  done
}

@test "help documents the brace-encoding rule" {
  run "$SCRIPT" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"{braces}"* ]]
}

@test "help points at the generated endpoint list" {
  run "$SCRIPT" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"references/endpoints.md"* ]]
}

@test "help names both key sources" {
  run "$SCRIPT" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"CALENDARPIPE_API_KEY"* ]]
  [[ "$output" == *"config.json"* ]]
}
