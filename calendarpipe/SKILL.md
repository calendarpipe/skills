---
name: calendarpipe
description: |
  Manage CalendarPipe hosted calendars and sync rules via the CalendarPipe REST API. Use this skill whenever the user mentions calendars, scheduling, events, invitations, RSVPs, syncing one calendar into another, filtering or transforming calendar events, polling for calendar updates, or CalendarPipe. Also trigger when the user wants to: create or manage calendar events, invite someone to a meeting, accept or decline an invitation, check what's on their calendar, mirror a work calendar into a personal one, or block out busy time.
license: MIT
compatibility: Requires a CalendarPipe Pro API key and HTTPS access to calendarpipe.com.
metadata:
  author: calendarpipe
  version: '2.0'
allowed-tools: Bash
---

# CalendarPipe

CalendarPipe exposes a REST API at `https://www.calendarpipe.com/api/v1`. It does two
things:

- **Hosted calendars** — cloud calendars you fully own. Each has its own email address so
  people can invite it, an `.ics` feed to subscribe to, and full API control.
- **Sync rules** — one calendar copied into another through a _gate function_, JavaScript
  that filters and rewrites each event on the way.

If the user asks you to edit events on a connected Google, Microsoft or Apple calendar,
**confirm with them before writing** — those are their real calendars.

## Making requests

All calls go through the wrapper script, which handles auth, encoding and errors:

```bash
CP="<skill-directory>/scripts/calendarpipe.sh"

$CP GET  /hosted-calendars
$CP POST /sync-rules '{"name":"Work → Personal","source":"...","target":"..."}'
```

**Composite calendar IDs must go in `{braces}`.** They contain `:`, and Apple CalDAV IDs
contain `/` as well; unbraced they corrupt the URL.

```bash
$CP GET '/calendars/{hosted:5e6ea455-...}/events?limit=100'
```

### Finding the right endpoint

Read [references/endpoints.md](references/endpoints.md). It lists every operation and shows
how to pull argument-level detail for one of them from the live spec, which is served from
production and therefore always current — prefer it over endpoint detail remembered from
anywhere else, including this file.

## Setup

Configuration lives at `~/.config/calendarpipe/config.json` (or `$XDG_CONFIG_HOME`), outside
the skill directory so that reinstalling or updating the skill cannot destroy it.

```json
{
  "api_token": "<the-token>",
  "calendar_id": "<hosted-calendar-uuid>",
  "feed_token": "<feed-token>"
}
```

A token inside a skill directory is one careless `git add` from publication, so the wrapper
moves a pre-2.0 `<skill-directory>/config.json` into place automatically on the next call and
tells you it did. You do not need to migrate anything by hand.

When you write the file yourself, `chmod 600` it.

If no config exists, walk the user through it:

1. **Get a key.** Ask them to create one at calendarpipe.com → Settings → API Keys. You
   cannot create it for them.
2. **Verify it.** `$CP GET /hosted-calendars`. If they already have calendars, show them and
   ask which to use.
3. **Create one if needed.** `$CP POST /hosted-calendars '{"name":"...","organizerDisplayName":"..."}'`
   Always set `organizerDisplayName` — it is what attendees see instead of the raw
   `cal-*@in.calendarpipe.com` address.
4. **Save** `id` as `calendar_id` and `feedToken` as `feed_token`, then tell the user their
   calendar email — the response's `calendarEmail`, which is not derived from `feedToken` —
   and feed URL `https://www.calendarpipe.com/feed/<feed_token>`.

Authentication resolves `$CALENDARPIPE_API_KEY` first, then `api_token` from the config file.

## When to loop in a human

Some things cannot be done through the API. **Stop and ask** when you hit:

| Situation                          | What the human must do                                |
| ---------------------------------- | ----------------------------------------------------- |
| No API key                         | calendarpipe.com → Settings → API Keys, then share it |
| `402 Payment Required`             | Upgrade to Pro at Settings → Billing                  |
| Need Google/Microsoft/Apple events | Connect the account at Connections                    |
| `feedToken` was regenerated        | Share the new feed URL; `calendarEmail` is unchanged  |
| Webhook URL unreachable            | A public HTTPS endpoint must exist before registering |

Never try to create API keys, manage billing, or connect OAuth providers yourself.

## Events

Create an event with attendees and invitations are sent automatically — you do not need to
call `/invite`, which exists only to re-send to attendees still on `NEEDS-ACTION`:

```bash
$CP POST '/calendars/{hosted:<calendar_id>}/events' '{
  "title": "Team Standup",
  "start": {"dateTime": "2026-08-20T10:00:00Z", "timeZone": "Europe/Prague"},
  "end":   {"dateTime": "2026-08-20T10:30:00Z", "timeZone": "Europe/Prague"},
  "attendees": [{"email": "alice@example.com"}]
}'
```

Read them back with `GET /calendars/{...}/events?start=...&end=...`, or across every
connected account with `GET /events`. Attendee RSVPs appear as `status` on each attendee:
`NEEDS-ACTION`, `ACCEPTED`, `DECLINED`, `TENTATIVE`.

To cancel and notify everyone, `POST /calendars/{hosted:<id>}/events/<eventId>/cancel`.

## Invitations

**Every invitation gets a response.** When you find pending ones, show them to the user and
respond immediately — never leave an event unacknowledged.

```bash
$CP GET  '/hosted-calendars/{<calendar_id>}/invitations?status=pending'
$CP POST '/hosted-calendars/{<calendar_id>}/invitations/{<event_uid>}/respond' '{"status":"ACCEPTED"}'
```

Valid: `ACCEPTED`, `DECLINED`, `TENTATIVE`. This emails a `METHOD:REPLY` to the organizer.

For real-time delivery instead of polling, register a webhook with
`PUT /hosted-calendars/{<id>}/webhook`; verify the HMAC signature before trusting a payload.

## Sync rules

A sync rule copies events from one calendar to another, passing each through a gate function.
Use them when the user wants a work calendar mirrored into a personal one, busy time blocked
out, or event details stripped before they are shared.

**Calendar references** name each side:

| Reference                            | Meaning                                     | Side        |
| ------------------------------------ | ------------------------------------------- | ----------- |
| `<accountUUID>:<providerCalendarId>` | A connected Google/Microsoft/Apple calendar | either      |
| `hosted:<uuid>`                      | A CalendarPipe hosted calendar              | either      |
| `ics:<uuid>`                         | A subscribed ICS feed                       | source only |
| `invitation:<email>`                 | Deliver as email invitations (Pro)          | target only |

Get valid references from `$CP GET /calendars`, which lists every connected account with its
calendars, plus ICS connections.

```bash
$CP POST /sync-rules '{
  "name": "Work → Personal",
  "source": "hosted:5e6ea455-...",
  "target": "acc-uuid:primary",
  "enabled": true
}'
```

`name`, `source` and `target` are required; `code` and `enabled` are optional. Omitting
`code` uses the default gate, which copies events unchanged.

### Writing a gate function

The gate is called once per event as a global `gate(event)` — **not exported, and it does not
return a modified event.** It returns whether the event syncs, and optionally how to change it
on the way:

```js
function gate(event) {
  if (event.durationMinutes < 30) {
    return { pass: false, reason: 'Meeting too short' };
  }
  return { pass: true, transform: { title: '[SYNCED] ' + event.title } };
}
```

`return true` / `return false` are shorthand for `{ pass: true }` / `{ pass: false }`.
Returning the event object itself does nothing — a common mistake.

|             |                                                                  |
| ----------- | ---------------------------------------------------------------- |
| `pass`      | required; `false` blocks the event                               |
| `reason`    | why it was blocked, ≤200 chars, only read when `pass` is `false` |
| `transform` | only read when `pass` is `true`                                  |

`transform` accepts `title`, `description`, `location`, `visibility`
(`default`/`public`/`private`), `showAs` (`free`/`busy`), `type`
(`default`/`outOfOffice`), `autoDecline`, `preBufferMinutes`, `postBufferMinutes` — and
nothing else. Times and attendees cannot be rewritten.

`event` carries `title`, `description`, `location`, `start`/`end`, `isAllDay`, `status`,
`responseStatus`, `showAs`, `type`, `attendees`, `organizer`, `recurrence`, plus the derived
`durationMinutes`, `dayOfWeek`, `hour`, `isWeekday`, `attendeeCount`, and
`event.matches(pattern)` for case-insensitive text matching.

**Test a gate before saving it.** The dry run executes the code against real events from the
source and returns what each event became:

```bash
$CP POST /sync-rules/dry-run '{
  "code": "function gate(event) {\n  return { pass: true, transform: { title: \"Busy\", showAs: \"free\" } };\n}",
  "source": "hosted:5e6ea455-...",
  "limit": 5
}'
```

Each result carries `input`, `output`, `passed`, `transformed` and any `errors`, so you can
show the user exactly what would land on the target before creating the rule.

Pass `ruleId` instead of `source` to test against an existing rule. `limit` caps how many
events come back; the spec carries its default and maximum. Check `eventsSource` in the
response: `real` means it ran against the user's actual events, `sample` means the source had
none available and fixtures were used — so a clean sample run is weaker evidence than a clean
real one.

Updating a rule takes `name`, `code` and `enabled` only — **`source` and `target` cannot be
changed.** Moving a sync to different calendars means deleting the rule and creating a new
one, which the user should be told before you do it.

Force a full re-sync with `POST /sync-rules/{id}/resync`; it returns `202` and runs in the
background.

## Errors

| Code  | Meaning                                        |
| ----- | ---------------------------------------------- |
| `400` | Validation failed — read `details` in the body |
| `401` | Missing or invalid API key                     |
| `402` | Pro plan required — a human must upgrade       |
| `404` | Not found, or not owned by this key            |
| `502` | Upstream provider error                        |

The wrapper prints the response body and exits non-zero on any of these, so the `details`
array is always available to correct the request.
