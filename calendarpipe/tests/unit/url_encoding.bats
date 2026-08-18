#!/usr/bin/env bats
# Composite calendar IDs must be URL-encoded. This is the highest-risk area —
# the ':' separator breaks URLs if not encoded, and Apple CalDAV IDs contain
# '/' as well, which would otherwise be read as a path separator.

load ../test_helper

@test "encodes the colon in a hosted: prefix" {
  run "$SCRIPT" GET '/calendars/{hosted:abc123}/events'
  [ "$status" -eq 0 ]
  [[ "$(curl_url)" == *"hosted%3Aabc123"* ]]
  [[ "$(curl_url)" != *"hosted:abc123"* ]]
}

@test "encodes colon AND slash in account:provider/sub composite IDs" {
  run "$SCRIPT" GET '/calendars/{acc-uuid:provider/family}/events'
  [ "$status" -eq 0 ]
  [[ "$(curl_url)" == *"acc-uuid%3Aprovider%2Ffamily"* ]]
}

@test "encodes an Apple CalDAV URL used as a calendar ID" {
  run "$SCRIPT" GET '/calendars/{acc-1:https://caldav.icloud.com/123/calendars/work/}/events'
  [ "$status" -eq 0 ]
  [[ "$(curl_url)" == *"https%3A%2F%2Fcaldav.icloud.com%2F123%2Fcalendars%2Fwork%2F"* ]]
}

@test "leaves an unbraced path untouched" {
  run "$SCRIPT" GET /calendars/abc-def-123/events
  [ "$status" -eq 0 ]
  [[ "$(curl_url)" == *"/calendars/abc-def-123/events" ]]
}

@test "preserves path separators outside braces" {
  run "$SCRIPT" POST '/hosted-calendars/{cal-1}/invitations/{uid-1}/respond' '{"status":"ACCEPTED"}'
  [ "$status" -eq 0 ]
  [[ "$(curl_url)" == *"/hosted-calendars/cal-1/invitations/uid-1/respond" ]]
}

@test "encodes spaces" {
  run "$SCRIPT" GET '/calendars/{my calendar}/events'
  [ "$status" -eq 0 ]
  [[ "$(curl_url)" == *"my%20calendar"* ]]
}

@test "encodes non-ASCII per UTF-8 byte, not per codepoint" {
  run "$SCRIPT" GET '/calendars/{café}/events'
  [ "$status" -eq 0 ]
  [[ "$(curl_url)" == *"caf%C3%A9"* ]]
}

@test "rejects unbalanced braces rather than building a corrupt URL" {
  run "$SCRIPT" GET '/calendars/{hosted:abc/events'
  [ "$status" -eq 1 ]
  [[ "$output" == *"unbalanced braces"* ]]
}

# Balanced but out of order — a count-only check would accept this and silently
# duplicate the tail of the path.
@test "rejects a closing brace that precedes its opening brace" {
  run "$SCRIPT" GET '/calendars/}abc{def'
  [ "$status" -eq 1 ]
  [[ "$output" == *"closing brace before opening"* ]]
}

@test "rejects nested braces" {
  run "$SCRIPT" GET '/calendars/{a{b}c}/events'
  [ "$status" -eq 1 ]
  [[ "$output" == *"nested braces"* ]]
}
