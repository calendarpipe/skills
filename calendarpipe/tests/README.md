# Tests for `calendarpipe.sh`

Two tiers:

- **unit/** — offline and fast. Mocks `curl` and asserts on URL construction, encoding,
  methods, headers, bodies and exit codes. No token or network needed.
- **integration/** — opt-in, hits the real API with a **Pro** key in
  `$CALENDARPIPE_API_KEY` (sync-rule endpoints answer 402 on free). Without the key its
  tests skip rather than fail. Point them at a local API with
  `CALENDARPIPE_BASE_URL=http://localhost:3000`.

## Install bats-core

```bash
brew install bats-core
```

## Run

```bash
cd calendarpipe/tests
./run.sh                 # unit only
./run.sh --integration   # also hits the real API
```

Or directly: `bats unit`, or `bats unit/help.bats` for one file.

## How the unit tests work

The mock at `tests/mocks/curl` is prepended to `$PATH` during setup. It records every argument
passed to `curl` — one per line — then prints a stub response. Tests inspect that log through
helpers in `test_helper.bash`:

| Helper                  | Returns                                    |
| ----------------------- | ------------------------------------------ |
| `curl_url`              | The URL (always the last argument)         |
| `curl_method`           | Value after `-X`, or `"GET"`               |
| `curl_body`             | Value after `-d`                           |
| `curl_header "Prefix:"` | First `-H` value starting with that prefix |
| `curl_log`              | Full argv, one per line                    |

`test_helper.bash` defines `setup`/`teardown` itself, so mocking is **opt-out**, not opt-in —
a new unit file that forgot them would otherwise run against real curl with the developer's
real token. It also exports `$CALENDARPIPE_API_KEY` and points `$XDG_CONFIG_HOME` at an empty
temp directory. Integration tests override both to reach the network.

Stub the response with `MOCK_CURL_RESPONSE`. The wrapper reads the HTTP status from a trailing
line, so an error case looks like:

```bash
export MOCK_CURL_RESPONSE='{"error":"Validation failed"}
400'
```

## Adding a test

```bash
@test "my new case" {
  run "$SCRIPT" GET '/calendars/{hosted:abc}/events'
  [ "$status" -eq 0 ]
  [[ "$(curl_url)" == *"hosted%3Aabc"* ]]
}
```

## What's not covered

Anything that sends real email stays manual, because there is no way to assert on it without
a human reading an inbox: inbound invitations (someone must email-invite the hosted calendar),
cancellations, and re-invites. Test those with yourself as the attendee. External-calendar
endpoints likewise need a connected Google/Microsoft/Apple account.
