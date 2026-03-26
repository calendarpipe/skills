---
name: calendarpipe
description: |
  Manage a hosted CalendarPipe calendar via the CalendarPipe REST API. Use this skill whenever the user mentions calendars, scheduling, events, invitations, RSVPs, polling for calendar updates, or CalendarPipe. Also trigger when the user wants to: create or manage calendar events, invite someone to a meeting, accept or decline an invitation, check what's on their calendar, or poll for new invitations. If the user mentions "CalendarPipe", "hosted calendar", "calendar feed", or "calendar invites", always use this skill.
---

# CalendarPipe Skill

This skill lets you operate a **hosted calendar** through the [CalendarPipe API](https://www.calendarpipe.com). A hosted calendar is a cloud calendar you fully own — it has its own email address so people can invite it, an `.ics` feed you can subscribe to, and a full REST API for creating events, sending invitations, and responding to RSVPs.

## First-Time Setup

Before doing any calendar work, check whether a config file exists at `<skill-directory>/config.json`. If it does, read it and verify the tokens are present. If it doesn't (or is missing fields), walk the user through setup step by step.

### Step 1 — Get the API token

Tell the user:

> To get started, I need a CalendarPipe API key. You can create one at https://www.calendarpipe.com (in your dashboard under API keys).
>
> Once you have it, please save it by telling me the token. I'll store it in my config file.

When the user provides the token, write it to `<skill-directory>/config.json`:

```json
{
  "api_token": "<the-token>",
  "calendar_id": "",
  "feed_token": ""
}
```

### Step 2 — Verify the token

Verify the token works by calling the "list hosted calendars" endpoint:

```bash
curl -s -H "Authorization: Bearer <api_token>" \
  https://www.calendarpipe.com/api/v1/hosted-calendars
```

If the response contains hosted calendars, show them to the user — they may already have one they want to use. If the token is invalid (401), tell the user and ask them to double-check.

### Step 3 — Create or select a hosted calendar

If the user already has hosted calendars, ask which one to use. Otherwise, ask what they'd like to name their new calendar.

To create one:

```bash
curl -s -X POST \
  -H "Authorization: Bearer <api_token>" \
  -H "Content-Type: application/json" \
  -d '{"name": "<calendar-name>"}' \
  https://www.calendarpipe.com/api/v1/hosted-calendars
```

The response includes the `id` and `feedToken`. Save both to `config.json`:

```json
{
  "api_token": "<the-token>",
  "calendar_id": "<hosted-calendar-id>",
  "feed_token": "<feed-token>"
}
```

Tell the user their calendar's email address (for receiving invites from others):

> Your calendar email is: `cal-<feed_token>@in.calendarpipe.com`
>
> People can invite this address to their events, and you'll see the invitations show up here.

Also mention the `.ics` feed URL they can subscribe to in any calendar app:

> You can subscribe to your calendar feed at:
> `https://www.calendarpipe.com/api/v1/feeds/<feed_token>.ics`

Setup is complete. From now on, all operations target this specific hosted calendar.

---

## Reading Config

At the start of every invocation (after setup is done), read `<skill-directory>/config.json` to load `api_token`, `calendar_id`, and `feed_token`. All API calls use these values.

Assign the helper script path to a variable for convenience:

```bash
CP="<skill-directory>/scripts/calendarpipe.sh"
```

Run `$CP --help` or see the API reference at `<skill-directory>/references/api.md` for full endpoint documentation.

---

## Core Operations

### Poll your calendar for events

This is the most common operation. Use the events endpoint with date filters to see what's coming up:

```bash
$CP list-events "$TOKEN" "$CAL_ID" "<start_iso>" "<end_iso>"
```

When showing events to the user, present them in a readable format: title, date/time, attendees and their RSVP status, location if set.

### Check for inbound invitations

When someone invites your calendar email to an event, it appears as an inbound invitation. Poll for these regularly:

```bash
$CP list-invitations "$TOKEN" "$CAL_ID" pending
```

**Important**: Every invitation should get a response. Never leave an invitation without replying — either accept, decline, or mark tentative. This is a core principle of this calendar: no event should sit unacknowledged.

### Respond to an invitation (RSVP)

When showing the user a pending invitation, always prompt them for a response. To accept:

```bash
$CP respond "$TOKEN" "$CAL_ID" "<event_uid>" ACCEPTED
```

Valid statuses: `ACCEPTED`, `DECLINED`, `TENTATIVE`.

This sends a METHOD:REPLY email back to the organizer automatically.

### Create an event and invite attendees

To schedule something new, create the event with attendees listed. Invitations are sent automatically to all attendees — no separate invite call is needed.

```bash
$CP create-event "$TOKEN" "$CAL_ID" '<event_json>'
```

The event JSON should follow this structure:
```json
{
  "title": "Team Standup",
  "start": {"dateTime": "2026-03-25T10:00:00Z", "timeZone": "America/New_York"},
  "end": {"dateTime": "2026-03-25T10:30:00Z", "timeZone": "America/New_York"},
  "attendees": [{"email": "alice@example.com"}, {"email": "bob@example.com"}]
}
```

### Check attendee responses

After inviting someone, you can check whether they've accepted by fetching the event details and inspecting the `attendees` array. Each attendee has a `status` field: `NEEDS-ACTION`, `ACCEPTED`, `DECLINED`, or `TENTATIVE`.

```bash
$CP list-events "$TOKEN" "$CAL_ID"
```

Look at the attendees on the specific event and report their status to the user.

### Update or cancel events

To modify an event (change time, add attendees, update title):

```bash
$CP update-event "$TOKEN" "<event_id>" '<update_json>'
```

To cancel and notify all attendees:

```bash
$CP cancel-event "$TOKEN" "$CAL_ID" "<event_id>"
```

This sends a METHOD:CANCEL email to every attendee.

---

## Pulling all calendars (connected accounts)

The user may have connected external calendars (Google, Microsoft, Apple) in addition to their hosted calendar. To see all connected accounts:

```bash
$CP list-all-calendars "$TOKEN"
```

To see events across *all* calendars (not just the hosted one):

```bash
$CP list-all-events "$TOKEN" "<start_iso>" "<end_iso>"
```

This merged view is useful when the user wants a full picture of their schedule.

---

## Workflow Summary

A typical session looks like this:

1. Load config (or run setup if first time)
2. Poll for new invitations → show them to user → respond to each one
3. Check upcoming events → report schedule
4. Create new events if requested (invitations are sent automatically to attendees)
5. Follow up on attendee responses

The guiding principle: **every invitation gets a response**. When you find pending invitations, always ask the user how to respond and then do it immediately.
