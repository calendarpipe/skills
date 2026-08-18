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

This skill delegates all calendar I/O to the **calendarpipe** skill. Confirm calendarpipe is installed and has been set up (it manages the API token and hosted calendar in `~/.config/calendarpipe/config.json`). If that config is missing, defer to its first-time setup flow before proceeding here.

## First-Time Setup

Configuration and state live at `~/.config/calendarpipe/agent-calendar/` (honouring
`$XDG_CONFIG_HOME`), outside the skill directory — updating or reinstalling the skill would
otherwise destroy the scheduled-task state below.

**Migrating an older install:** if `<skill-dir>/config.json` or `<skill-dir>/state.json`
exists, move each one to the new directory and tell the user what moved. If a file of that
name is already there, leave the old one alone and say so — never overwrite a live config or
a state file tracking scheduled crons.

Before doing any work, check whether `~/.config/calendarpipe/agent-calendar/config.json` exists. If it does, read it and verify `trusted_senders` is a non-empty list and `timezone` is set. If it doesn't exist (or is missing fields), walk the user through setup:

1. Ask: _"Which email address(es) should I auto-accept invitations from? I'll only schedule tasks from senders you explicitly trust. You can list more than one — e.g. your personal and work emails."_
2. Ask for their timezone, suggesting a detected default from `date +%Z` (e.g. `Europe/Prague`, `America/New_York`). The timezone is used when scheduling cron jobs so events fire at the right local time.
3. Write `~/.config/calendarpipe/agent-calendar/config.json`:

   ```json
   {
     "trusted_senders": ["user@example.com"],
     "timezone": "Europe/Prague",
     "cron_model": "sonnet",
     "cron_session": "isolated"
   }
   ```

`cron_model` and `cron_session` have sensible defaults (`sonnet`, `isolated`) — only surface them if the user asks. They control which model runs the scheduled task and whether it runs in an isolated session.

At the start of every invocation (after setup), load `config.json` and use `trusted_senders`, `timezone`, `cron_model`, and `cron_session` from it. Never hardcode these values.

## State File

`~/.config/calendarpipe/agent-calendar/state.json` tracks everything:

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

Ask calendarpipe to list pending invitations on the hosted calendar. For each one:

- **From a trusted sender** (sender email is in `config.trusted_senders`): ask calendarpipe to respond `ACCEPTED` to that invitation, then proceed to step 2.
- **From anyone else**: notify the user and ask how to respond. Do not schedule anything yet.

### 1b. Catch Accepted-but-Unscheduled Invitations

The pending filter only shows unresponded invitations. If a previous session accepted an invitation but crashed before scheduling the cron, step 1 won't see it.

To recover, ask calendarpipe to list **all** invitations (no status filter). For each invitation returned:

- Check if the `event_uid` already exists in `state.json`.
- If it does NOT exist in state, and the sender is in `config.trusted_senders`:
  - It was accepted but never tracked. Proceed to step 2 to schedule a cron (or execute immediately if the event start time has already passed).
- If it already exists in state → skip (already handled).

**If the event start time has already passed:** Do not schedule a cron in the past. Instead, execute the task inline immediately and record it in state with `status: "executed"`.

### 2. Schedule Cron for Accepted Task

After accepting (or recovering an accepted-but-unscheduled task), create a one-shot cron job:

```bash
openclaw cron add \
  --name "cal-task:<first-8-chars-of-event-uid>" \
  --at "<event_start_iso>" \
  --tz "<config.timezone>" \
  --session <config.cron_session> \
  --model <config.cron_model> \
  --announce \
  --delete-after-run \
  --json \
  --message "Calendar task from event '<title>'. Task: <description>. Execute this task now and deliver the result."
```

Capture the `id` from JSON output. Save to `state.json` under the event UID.

### 3. Reconcile (every heartbeat run)

For each entry in `state.json` where `status == "scheduled"`:

1. Verify the cron still exists: `openclaw cron list --json` and check for the `cronId`.
2. Ask calendarpipe to list events in a narrow window around `startAt` to confirm the event still exists.
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
