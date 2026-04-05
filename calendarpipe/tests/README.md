# Tests for `calendarpipe.sh`

Two tiers:

- **unit/** — offline, fast, no API token needed. Mocks `curl` and asserts on
  URL construction, HTTP methods, headers, and request bodies. 53 tests.
- **integration/** — opt-in, hits the real CalendarPipe API. Requires a token
  in `.env`. See `integration/README.md`.

## Install bats-core

```bash
brew install bats-core
```

## Run unit tests

```bash
cd calendarpipe/tests
./run.sh                 # default — unit only, no env or network needed
```

Or directly with bats:

```bash
bats calendarpipe/tests/unit              # whole suite
bats calendarpipe/tests/unit/help.bats    # a single file
```

## Run unit + integration

```bash
cd calendarpipe/tests
./run.sh --integration   # also hits the real API (requires .env)
```

## How the unit tests work

The mock at `tests/mocks/curl` is prepended to `$PATH` during test setup. It
records every argument passed to `curl` (one per line) to a temp file, then
prints a stub JSON response. Tests then inspect the log via helpers in
`test_helper.bash`:

| Helper | Returns |
|---|---|
| `curl_url` | The URL (last arg) |
| `curl_method` | Value after `-X`, or `"GET"` |
| `curl_body` | Value after `-d` |
| `curl_header "Prefix:"` | First `-H` value starting with that prefix |
| `curl_log` | Full argv, one per line |

## Adding a new test case

1. Pick the right file (or create one under `unit/`)
2. Start with `load ../test_helper` and `setup()` / `teardown()` calling
   `setup_mock_curl` / `teardown_mock_curl`
3. Call the script via `run "$SCRIPT" <cmd> "$TOKEN" ...`
4. Assert on `$status`, `$output`, and the curl log helpers

Example:

```bash
@test "my new case" {
  run "$SCRIPT" list-events "$TOKEN" "hosted:abc"
  [ "$status" -eq 0 ]
  [[ "$(curl_url)" == *"expected-substring"* ]]
}
```

## What's not covered

- Invitation flows (`respond`, `list-invitations` on live data) — requires a
  human to email-invite the hosted calendar. Manual QA only.
- `cancel-event` / `resend-invite` integration — sends real emails to
  attendees. Test manually with yourself as attendee.
- External-calendar endpoints (`list-all-events`, `list-all-calendars`)
  depend on connected Google/Microsoft/Apple accounts. Verify manually.
