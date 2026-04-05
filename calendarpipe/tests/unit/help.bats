#!/usr/bin/env bats

load ../test_helper

setup() { setup_mock_curl; }
teardown() { teardown_mock_curl; }

@test "help prints usage and exits 0" {
  run "$SCRIPT" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"CalendarPipe CLI helper"* ]]
  [[ "$output" == *"Usage:"* ]]
}

@test "--help flag works" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "-h flag works" {
  run "$SCRIPT" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "no arguments prints help and exits 0" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "unknown command exits 1 and points to help" {
  run "$SCRIPT" totally-bogus-cmd
  [ "$status" -eq 1 ]
  [[ "$output" == *"Unknown command: totally-bogus-cmd"* ]]
  [[ "$output" == *"help"* ]]
}

@test "help lists every command in the dispatch table" {
  run "$SCRIPT" help
  [ "$status" -eq 0 ]
  for cmd in list-events list-all-events create-event update-event delete-event \
             cancel-event list-invitations respond list-calendars list-all-calendars \
             create-calendar delete-calendar resend-invite; do
    [[ "$output" == *"$cmd"* ]] || { echo "missing command: $cmd"; return 1; }
  done
}
