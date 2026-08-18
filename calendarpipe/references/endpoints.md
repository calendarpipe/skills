# CalendarPipe API — endpoint index

<!-- Generated from the CalendarPipe OpenAPI spec. Do not edit by hand. -->

Every operation the API exposes. For argument-level detail — parameters, request
body, response shape, examples — fetch the one operation you need instead of
reading the whole spec:

```bash
curl -s https://www.calendarpipe.com/api/v1/openapi.json \
  | jq '.paths["/api/v1/sync-rules"]'
```

```
GET     /api/v1/calendars — List connected calendar accounts with their calendars
GET     /api/v1/calendars/{id}/events — List events for a calendar
POST    /api/v1/calendars/{id}/events — Create an event on a calendar
POST    /api/v1/calendars/{id}/events/{eventId}/cancel — Send cancellation to all attendees
POST    /api/v1/calendars/{id}/events/{eventId}/invite — Send invitations to event attendees
GET     /api/v1/events — List events across all calendars
PATCH   /api/v1/events/{eventId} — Update an event
DELETE  /api/v1/events/{eventId} — Delete an event
GET     /api/v1/hosted-calendars — List hosted calendars
POST    /api/v1/hosted-calendars — Create a hosted calendar
GET     /api/v1/hosted-calendars/{id} — Get a hosted calendar
PATCH   /api/v1/hosted-calendars/{id} — Update a hosted calendar
DELETE  /api/v1/hosted-calendars/{id} — Delete a hosted calendar
GET     /api/v1/hosted-calendars/{id}/invitations — List inbound invitations
POST    /api/v1/hosted-calendars/{id}/invitations/{uid}/respond — Respond to an invitation (RSVP)
POST    /api/v1/hosted-calendars/{id}/regenerate-token — Regenerate feed token
PUT     /api/v1/hosted-calendars/{id}/webhook — Register a webhook for invitation delivery
DELETE  /api/v1/hosted-calendars/{id}/webhook — Remove webhook registration
GET     /api/v1/sync-rules — List sync rules
POST    /api/v1/sync-rules — Create a sync rule
GET     /api/v1/sync-rules/{id} — Get a sync rule
PATCH   /api/v1/sync-rules/{id} — Update a sync rule
DELETE  /api/v1/sync-rules/{id} — Delete a sync rule
POST    /api/v1/sync-rules/{id}/resync — Force a full re-sync
POST    /api/v1/sync-rules/dry-run — Test gate code against events
```
