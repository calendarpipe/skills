# CalendarPipe API Reference

Base URL: `https://www.calendarpipe.com`
Auth: `Authorization: Bearer <api_token>`

All request/response bodies are JSON. Dates use ISO 8601 format with timezone offset.

---

## Table of Contents

1. [Hosted Calendars](#hosted-calendars)
2. [Events on a Calendar](#events-on-a-calendar)
3. [Events Across All Calendars](#events-across-all-calendars)
4. [Event Mutations](#event-mutations)
5. [Invitations (Outbound)](#invitations-outbound)
6. [Invitations (Inbound)](#invitations-inbound)
7. [Webhooks](#webhooks)
8. [Connected Calendar Accounts](#connected-calendar-accounts)
9. [Schemas](#schemas)

---

## Hosted Calendars

### Create a hosted calendar

```
POST /api/v1/hosted-calendars
```

Body:
```json
{
  "name": "My Calendar",            // required, 1-100 chars
  "description": "Team meetings",   // optional, max 500
  "color": "#3B82F6",               // optional, hex
  "timezone": "America/New_York",   // optional, default UTC
  "organizerDisplayName": "Bot"     // optional, shown to attendees
}
```

Response `201`:
```json
{
  "data": {
    "id": "uuid",
    "name": "My Calendar",
    "description": null,
    "color": null,
    "timezone": "America/New_York",
    "feedToken": "uuid",
    "ctag": 1,
    "createdAt": "...",
    "updatedAt": "...",
    "organizerDisplayName": null,
    "calendarEmail": "cal-<feedToken>@in.calendarpipe.com"
  }
}
```

### List hosted calendars

```
GET /api/v1/hosted-calendars
```

Response `200`: `{ "data": [HostedCalendar, ...] }`

### Get a hosted calendar

```
GET /api/v1/hosted-calendars/{id}
```

### Update a hosted calendar

```
PATCH /api/v1/hosted-calendars/{id}
```

Body: any subset of `name`, `description`, `color`, `timezone`, `organizerDisplayName`.

### Delete a hosted calendar

```
DELETE /api/v1/hosted-calendars/{id}
```

Response `204`. Cascades to all events.

### Regenerate feed token

```
POST /api/v1/hosted-calendars/{id}/regenerate-token
```

Invalidates the previous `.ics` feed URL and generates a new `feedToken`.

---

## Events on a Calendar

### Calendar ID format

All calendar endpoints use **composite calendar IDs**:

| Format | Example | Description |
|--------|---------|-------------|
| `<accountUUID>:<calendarId>` | `5d284d6b-...:family@group.calendar.google.com` | External sub-calendar |
| `hosted:<uuid>` | `hosted:4afe317f-...` | Hosted calendar |
| `<accountUUID>` (bare) | `5d284d6b-...` | Defaults to primary calendar (backward compatible) |

Use `GET /api/v1/calendars` to discover available calendar IDs.

### List events for a specific calendar

```
GET /api/v1/calendars/{id}/events
```

`{id}` is a composite calendar ID (see format above).

Query params:
- `offset` (int, default 0) — pagination offset
- `limit` (int, 1-100, default 50) — page size
- `start` (ISO 8601 datetime) — events starting at or after
- `end` (ISO 8601 datetime) — events starting before

Response `200`:
```json
{
  "data": [ApiEvent, ...],
  "meta": { "offset": 0, "limit": 50, "total": 5, "has_more": false }
}
```

### Create an event

```
POST /api/v1/calendars/{id}/events
```

`{id}` is a composite calendar ID (see format above).

Body:
```json
{
  "title": "Team meeting",                                    // required
  "description": "Discuss roadmap",                           // optional
  "location": "Conference room",                              // optional
  "start": { "dateTime": "2026-03-10T10:00:00Z", "timeZone": "America/New_York" },  // required
  "end":   { "dateTime": "2026-03-10T11:00:00Z", "timeZone": "America/New_York" },  // required
  "isAllDay": false,                                          // optional
  "visibility": "default",                                    // optional: public|private|default
  "status": "confirmed",                                      // optional: confirmed|tentative|cancelled
  "attendees": [{ "email": "alice@example.com" }]             // optional
}
```

Response `201`: `{ "data": ApiEvent }`

---

## Events Across All Calendars

### List events (merged view)

```
GET /api/v1/events
```

Query params:
- `offset`, `limit`, `start`, `end` — same as calendar-specific events
- `calendarIds` (string, optional) — comma-separated list of composite calendar IDs to filter by. When omitted, returns events from the primary calendar of each account.

Returns events from connected calendar accounts merged together.

---

## Event Mutations

### Update an event

```
PATCH /api/v1/events/{eventId}
```

Query params:
- `accountId` (string) — required for external provider events, not needed for hosted events. Supports composite format (`<accountUUID>:<calendarId>`) to target a specific sub-calendar, or bare account UUID for primary.

Body: any subset of CreateEvent fields.

### Delete an event

```
DELETE /api/v1/events/{eventId}
```

Query params:
- `accountId` (string) — required for external provider events. Supports composite format (`<accountUUID>:<calendarId>`) to target a specific sub-calendar.

Response `204`.

---

## Invitations (Outbound)

**Note:** Invitations are sent automatically when attendees are included in event creation or added via update. You do not need to call the `/invite` endpoint explicitly.

### Send invitations to event attendees (manual re-send)

```
POST /api/v1/calendars/{id}/events/{eventId}/invite
```

- `{id}` must be `hosted:<calendarId>` format
- `{eventId}` is the synthetic event ID (`evt_*` format)
- Sends METHOD:REQUEST to all NEEDS-ACTION attendees
- Idempotent — safe to call multiple times
- Typically only needed to re-send invitations to attendees who haven't responded

Response `200`:
```json
{ "data": { "sent": 3, "skipped": 1 } }
```

### Cancel event (notify all attendees)

```
POST /api/v1/calendars/{id}/events/{eventId}/cancel
```

- `{id}` must be `hosted:<calendarId>` format (same as other endpoints)
- `{eventId}` is the synthetic event ID (`evt_*` format)
- Sends METHOD:CANCEL to ALL attendees regardless of response status

Response `200`: `{ "data": { "sent": 3, "skipped": 0 } }`

---

## Invitations (Inbound)

### List inbound invitations

```
GET /api/v1/hosted-calendars/{id}/invitations
```

Query params:
- `status` (string, optional) — filter by delivery status, e.g. `pending`, `delivered`

Returns invitations received by this hosted calendar, ordered oldest-first.

Response `200`:
```json
{
  "data": [
    {
      "id": "uuid",
      "event_uid": "evt-uid-12345",
      "organizer_email": "organizer@example.com",
      "payload": { ... },
      "delivery_status": "pending",
      "created_at": "2026-01-01T00:00:00.000Z"
    }
  ]
}
```

### Respond to an invitation (RSVP)

```
POST /api/v1/hosted-calendars/{id}/invitations/{uid}/respond
```

- `{uid}` is the `event_uid` from the invitation

Body:
```json
{ "status": "ACCEPTED" }
```

Valid values: `ACCEPTED`, `DECLINED`, `TENTATIVE`.

This updates the attendee status on the organizer's event and sends a METHOD:REPLY email back to the organizer.

---

## Webhooks

### Register a webhook

```
PUT /api/v1/hosted-calendars/{id}/webhook
```

Body:
```json
{
  "url": "https://your-agent.example.com/webhook",   // must be https
  "secret": "whsec_your-secret-here"                  // must start with whsec_
}
```

Payloads use standard-webhooks HMAC signature verification (headers: `webhook-id`, `webhook-timestamp`, `webhook-signature`).

### Remove webhook

```
DELETE /api/v1/hosted-calendars/{id}/webhook
```

Response `204`. Falls back to polling via the invitations endpoint.

---

## Connected Calendar Accounts

### List connected accounts

```
GET /api/v1/calendars
```

Returns all calendar accounts (Google, Microsoft, Apple, CalendarPipe) connected to the user, with their calendars listed. Each calendar has a composite ID that can be used with other endpoints.

Response `200`:
```json
{
  "data": [
    {
      "id": "abc-uuid-123",
      "provider": "google",
      "email": "user@example.com",
      "enabled": true,
      "createdAt": "...",
      "calendars": [
        { "id": "abc-uuid-123:user@example.com", "name": "Primary" },
        { "id": "abc-uuid-123:family@group.calendar.google.com", "name": "Family" }
      ]
    },
    {
      "id": "calendarpipe",
      "provider": "calendarpipe",
      "email": null,
      "enabled": true,
      "createdAt": null,
      "calendars": [
        { "id": "hosted:5e6ea455-...", "name": "My Agent Calendar" }
      ]
    }
  ]
}
```

---

## Schemas

### ApiEvent

```json
{
  "id": "evt_Z29vZ2xlOmFiYzEyMw",
  "calendarId": "abc-uuid-123:user@example.com",  // composite ID (accountUUID:calendarId) or hosted:uuid
  "provider": "google|microsoft|apple|calendarpipe",
  "providerEventId": "...",
  "title": "Meeting",
  "description": "...",
  "location": "...",
  "start": { ... },
  "end": { ... },
  "isAllDay": false,
  "status": "confirmed|tentative|cancelled",
  "visibility": "public|private|default",
  "attendees": [
    {
      "email": "alice@example.com",
      "displayName": "Alice",
      "status": "NEEDS-ACTION|ACCEPTED|DECLINED|TENTATIVE"
    }
  ],
  "organizer": { ... },
  "recurrence": null,
  "durationMinutes": 60,
  "dayOfWeek": 1,
  "hour": 9,
  "isWeekday": true,
  "attendeeCount": 3,
  "updatedAt": "..."
}
```

### Attendee status values

- `NEEDS-ACTION` — hasn't responded yet
- `ACCEPTED` — confirmed attendance
- `DECLINED` — declined the invite
- `TENTATIVE` — might attend
