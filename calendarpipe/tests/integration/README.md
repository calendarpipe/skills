# Integration tests

These tests hit the **real CalendarPipe API at `https://www.calendarpipe.com`**.
They are opt-in and require a real API token. Tests are **self-cleaning**:
they create throwaway resources and delete them at the end.

## Setup

```bash
cp ../../.env.example ../../.env
# edit calendarpipe/.env and set CALENDARPIPE_API_TOKEN
```

That's the only required env var. If it's not set, tests that need it are
**skipped**, not failed.

## Run

```bash
# from calendarpipe/tests/
./run.sh --integration      # unit + integration
bats integration            # integration only
```

## What the roundtrip does

1. Creates a hosted calendar named `bats-test-<timestamp>-<pid>`
2. Creates an event in it (year 2099, so it can't collide with real events)
3. Lists events and asserts the event is present
4. Deletes the event
5. Deletes the calendar

An `EXIT` trap runs cleanup even if the test aborts partway through — it
tries to delete both the event and the calendar, swallowing errors. If a run
is killed with SIGKILL you may be left with a leftover `bats-test-*` calendar;
delete it from your dashboard or re-run (names are unique per run).

## Not covered here (manual QA)

- **Invitation flow** (`respond`, `list-invitations` on live data) — requires
  a human to email-invite the hosted calendar.
- **`cancel-event` / `resend-invite`** — send real METHOD:CANCEL / invite
  emails to attendees. Test manually with your own email as attendee.
- **`list-all-events` / `list-all-calendars`** — depend on external calendar
  accounts (Google/Microsoft/Apple) being connected. Verify manually.
- **`update-event`** — low risk, covered by unit tests; easy to spot-check.
