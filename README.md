# Skills

A collection of [Agent Skills](https://agentskills.io) for calendar-driven automation. These skills give AI agents the ability to manage a hosted calendar and execute tasks on a schedule — turning calendar invitations into real actions.

## What's inside

### calendarpipe

Manage a hosted [CalendarPipe](https://www.calendarpipe.com) calendar — create events, send invitations, RSVP to inbound invites, check schedules, and poll for updates. Includes a helper script for common API operations and a full API reference.

### agent-calendar

Turn calendar invitations into scheduled cron jobs. When an invitation arrives with a task in its description, the skill accepts it and schedules a one-shot cron at the event's start time. Handles reconciliation (re-creating missing crons, cleaning up cancelled events) and crash recovery.

Depends on `calendarpipe` for API access and config.

## Installation

Clone this repo and symlink (or copy) the skill directories into your agent's skills folder.

### Claude Code

```bash
# Project-level (this project only)
mkdir -p .claude/skills
ln -s /path/to/skills/calendarpipe .claude/skills/calendarpipe
ln -s /path/to/skills/agent-calendar .claude/skills/agent-calendar

# User-level (all projects)
mkdir -p ~/.claude/skills
ln -s /path/to/skills/calendarpipe ~/.claude/skills/calendarpipe
ln -s /path/to/skills/agent-calendar ~/.claude/skills/agent-calendar
```

### VS Code (GitHub Copilot) / Cross-client

```bash
# Project-level
mkdir -p .agents/skills
ln -s /path/to/skills/calendarpipe .agents/skills/calendarpipe
ln -s /path/to/skills/agent-calendar .agents/skills/agent-calendar

# User-level
mkdir -p ~/.agents/skills
ln -s /path/to/skills/calendarpipe ~/.agents/skills/calendarpipe
ln -s /path/to/skills/agent-calendar ~/.agents/skills/agent-calendar
```

### Setup

After installing, the `calendarpipe` skill will walk you through first-time setup (API key, calendar selection) on first use. It stores credentials in `config.json` inside the skill directory — this file is gitignored and never committed.

`agent-calendar` uses the `calendarpipe` skill for API access and config, so it requires `calendarpipe` to be installed alongside it. `calendarpipe` works standalone.
