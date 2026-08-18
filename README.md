# CalendarPipe Skills

[Agent Skills](https://agentskills.io) that let AI agents run a calendar — manage events,
send and answer invitations, sync one calendar into another, and execute tasks on a schedule.

> **This repository is a read-only mirror.** It is generated from the CalendarPipe product
> repository on every release. Pull requests here cannot be merged — please
> [open an issue](https://github.com/calendarpipe/skills/issues) instead and we will land the
> change upstream.

## What's inside

### calendarpipe

Operate CalendarPipe through its REST API: hosted calendars, events, invitations and RSVPs,
and sync rules with their gate functions. Ships a transport wrapper for authenticated calls
and an endpoint index generated from the API's own OpenAPI spec.

### agent-calendar

Turns calendar invitations into scheduled work. When an invitation arrives carrying a task in
its description, the skill accepts it and schedules a one-shot cron at the event's start time,
reconciling on restart. Depends on `calendarpipe` for API access.

## Install

With the [`skills` CLI](https://github.com/vercel-labs/skills), which works with Claude Code,
Cursor, Copilot, Codex and 40+ other agents:

```bash
npx skills add calendarpipe/skills                       # both skills
npx skills add calendarpipe/skills --skill calendarpipe  # just the API skill
npx skills add calendarpipe/skills -g                    # all projects
```

Update later with `npx skills update`.

## Setup

On first use the `calendarpipe` skill walks you through getting an API key and choosing a
hosted calendar, storing both under `~/.config/calendarpipe/` — outside the skill directory,
so updating or reinstalling never disturbs them. Upgrading from v1.x needs nothing from you:
both skills move their old config across on first run.

Full setup and installation guide: **https://docs.calendarpipe.com/developers/skills**

## Requirements

- A CalendarPipe **Pro** API key — create one at
  [calendarpipe.com](https://www.calendarpipe.com) under Settings → API Keys.
- `curl`, and `jq` for reading the API spec.
- `bats-core` only if you want to run the test suite.

## Tests

```bash
cd calendarpipe/tests
./run.sh                # unit tests against a mocked curl
./run.sh --integration  # also hits the real API; needs $CALENDARPIPE_API_KEY
```

## Documentation

- [Agent Skills guide](https://docs.calendarpipe.com/developers/skills)
- [API reference](https://www.calendarpipe.com/api/v1/openapi.json)

## License

MIT — see [LICENSE](LICENSE).
