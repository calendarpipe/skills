---
name: agent-calendar
description: |
  Process CalendarPipe calendar invitations into scheduled cron tasks. Use during heartbeats or when asked to check calendar tasks. Handles: (1) accepting invitations from trusted senders, (2) scheduling one-shot cron jobs to execute event tasks at their start time, (3) reconciling state — verifying crons exist, cleaning up cancelled/deleted events. Triggers on: heartbeat calendar checks, "check calendar tasks", "process invitations", or any mention of scheduled calendar-driven tasks.
---

# Agent Calendar

Turn CalendarPipe invitations into deterministic cron-executed tasks.

## Concept

When an invitation arrives with a task in its description, don't rely on the next heartbeat to execute it. Instead, schedule a one-shot cron job at the event's start time. This guarantees execution regardless of session state.

## Prerequisites

Read `<skill-dir>/../calendarpipe/config.json` for `api_token`, `calendar_id`, and `feed_token`. The CalendarPipe CLI lives at `<skill-dir>/../calendarpipe/scripts/calendarpipe.sh`.

## State File

`<skill-dir>/state.json` tracks everything:

```json
{
  "tasks": {
    "<event_uid>": {
      "title": "Event title",
      "task": "Task from description",
      "startAt": "ISO timestamp",
      "cronId": "openclaw-cron-job-id",
      "cronName": "cal-task:<short-id>",
      "accepted": "ISO timestamp",
      "status": "scheduled|executed|cancelled"
    }
  }
}
```

Initialize with `{"tasks":{}}` if missing.

## Workflow

### 1. Check Pending Invitations

```bash
$CP list-invitations "$TOKEN" "$CAL_ID" pending
```

For each pending invitation:

- **From trusted sender** (currently: `jukben@gmail.com`): auto-accept via `$CP respond "$TOKEN" "$CAL_ID" "<event_uid>" ACCEPTED`, then proceed to step 2.
- **From anyone else**: notify the user and ask how to respond. Do not schedule anything yet.

### 1b. Catch Accepted-but-Unscheduled Invitations

The pending filter only shows unresponded invitations. If a previous session accepted an invitation but crashed or failed to schedule the cron, it will be invisible to step 1.

To recover:

```bash
$CP list-invitations "$TOKEN" "$CAL_ID"
```

For each invitation in the response:
- Check if the `event_uid` already exists in `state.json`.
- If it does NOT exist in state, and the invitation is from a trusted sender:
  - It was accepted but never tracked. Proceed to step 2 to schedule a cron (or execute immediately if the event start time has already passed).
- If it already exists in state → skip (already handled).

**If the event start time has already passed:** Do not schedule a cron in the past. Instead, execute the task inline immediately and record it in state with `status: "executed"`.

### 2. Schedule Cron for Accepted Task

After accepting (or recovering an accepted-but-unscheduled task), create a one-shot cron job:

```bash
openclaw cron add \
  --name "cal-task:<first-8-chars-of-event-uid>" \
  --at "<event_start_iso>" \
  --tz "Europe/Prague" \
  --session isolated \
  --model sonet \
  --announce \
  --delete-after-run \
  --json \
  --message "Calendar task from event '<title>'. Task: <description>. Execute this task now and deliver the result."
```

Capture the `id` from JSON output. Save to `state.json` under the event UID.

### 3. Reconcile (every heartbeat run)

For each entry in `state.json` where `status == "scheduled"`:

1. Verify the cron still exists: `openclaw cron list --json` and check for the `cronId`.
2. Check if the event still exists on the calendar: `$CP list-events "$TOKEN" "$CAL_ID" <range-around-startAt>`.
3. If event was deleted/cancelled but cron exists → `openclaw cron rm <cronId>`, set status to `cancelled`.
4. If cron is missing but event exists → re-create the cron (step 2).
5. If both gone → set status to `cancelled` and clean up.

Also clean up entries with `status == "executed"` or `status == "cancelled"` older than 7 days.

### 4. Report

After processing, report a brief summary:
- New tasks accepted and scheduled (with cron time)
- Any reconciliation actions taken
- Any invitations needing user input

If nothing changed, say so in one line.
