#!/usr/bin/env bash
# CalendarPipe CLI helper
#
# Usage:
#   calendarpipe.sh <command> <token> [args...]
#
# Commands:
#   list-events       <token> <calendar_id> [start_iso] [end_iso]
#   list-all-events   <token> [start_iso] [end_iso] [calendarIds]
#   create-event      <token> <calendar_id> <event_json>
#   update-event      <token> <event_id> <update_json>
#   delete-event      <token> <event_id>
#   cancel-event      <token> <cal_id> <event_id>
#   list-invitations  <token> <cal_id> [status]
#   respond           <token> <cal_id> <event_uid> <ACCEPTED|DECLINED|TENTATIVE>
#   list-calendars    <token>
#   list-all-calendars <token>
#   create-calendar   <token> <name> [timezone] [organizerDisplayName]
#   resend-invite     <token> <cal_id> <event_id>
#
# Calendar ID formats:
#   hosted:<uuid>                          — Hosted calendar
#   <accountUUID>:<providerCalendarId>     — External sub-calendar (e.g. Google Family)
#   <accountUUID>                          — External primary calendar (backward compat)

set -euo pipefail

BASE_URL="https://www.calendarpipe.com"

cmd="${1:?Usage: calendarpipe.sh <command> ...}"
shift

case "$cmd" in

  list-events)
    token="$1" cal_id="$2" start="${3:-}" end="${4:-}"
    # cal_id is a composite ID — pass it directly (URL-encoded)
    encoded_cal_id=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${cal_id}', safe=''))")
    url="${BASE_URL}/api/v1/calendars/${encoded_cal_id}/events?limit=100"
    [ -n "$start" ] && url="${url}&start=${start}"
    [ -n "$end" ] && url="${url}&end=${end}"
    curl -s -H "Authorization: Bearer ${token}" "${url}"
    ;;

  list-all-events)
    token="$1" start="${2:-}" end="${3:-}" calendar_ids="${4:-}"
    url="${BASE_URL}/api/v1/events?limit=100"
    [ -n "$start" ] && url="${url}&start=${start}"
    [ -n "$end" ] && url="${url}&end=${end}"
    [ -n "$calendar_ids" ] && url="${url}&calendarIds=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${calendar_ids}', safe=''))")"
    curl -s -H "Authorization: Bearer ${token}" "${url}"
    ;;

  create-event)
    token="$1" cal_id="$2" event_json="$3"
    # cal_id is a composite ID — pass it directly (URL-encoded)
    encoded_cal_id=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${cal_id}', safe=''))")
    curl -s -X POST \
      -H "Authorization: Bearer ${token}" \
      -H "Content-Type: application/json" \
      -d "${event_json}" \
      "${BASE_URL}/api/v1/calendars/${encoded_cal_id}/events"
    ;;

  update-event)
    token="$1" event_id="$2" update_json="$3"
    curl -s -X PATCH \
      -H "Authorization: Bearer ${token}" \
      -H "Content-Type: application/json" \
      -d "${update_json}" \
      "${BASE_URL}/api/v1/events/${event_id}"
    ;;

  delete-event)
    token="$1" event_id="$2"
    curl -s -X DELETE \
      -H "Authorization: Bearer ${token}" \
      "${BASE_URL}/api/v1/events/${event_id}"
    ;;

  cancel-event)
    token="$1" cal_id="$2" event_id="$3"
    encoded_cal_id=$(python3 -c "import urllib.parse; print(urllib.parse.quote('hosted:${cal_id}', safe=''))")
    curl -s -X POST \
      -H "Authorization: Bearer ${token}" \
      "${BASE_URL}/api/v1/calendars/${encoded_cal_id}/events/${event_id}/cancel"
    ;;

  list-invitations)
    token="$1" cal_id="$2" status="${3:-}"
    url="${BASE_URL}/api/v1/hosted-calendars/${cal_id}/invitations"
    [ -n "$status" ] && url="${url}?status=${status}"
    curl -s -H "Authorization: Bearer ${token}" "${url}"
    ;;

  respond)
    token="$1" cal_id="$2" event_uid="$3" rsvp_status="$4"
    curl -s -X POST \
      -H "Authorization: Bearer ${token}" \
      -H "Content-Type: application/json" \
      -d "{\"status\": \"${rsvp_status}\"}" \
      "${BASE_URL}/api/v1/hosted-calendars/${cal_id}/invitations/${event_uid}/respond"
    ;;

  list-calendars)
    token="$1"
    curl -s -H "Authorization: Bearer ${token}" \
      "${BASE_URL}/api/v1/hosted-calendars"
    ;;

  list-all-calendars)
    token="$1"
    curl -s -H "Authorization: Bearer ${token}" \
      "${BASE_URL}/api/v1/calendars"
    ;;

  create-calendar)
    token="$1" name="$2" timezone="${3:-UTC}" organizer="${4:-}"
    body="{\"name\": \"${name}\", \"timezone\": \"${timezone}\""
    [ -n "$organizer" ] && body="${body}, \"organizerDisplayName\": \"${organizer}\""
    body="${body}}"
    curl -s -X POST \
      -H "Authorization: Bearer ${token}" \
      -H "Content-Type: application/json" \
      -d "${body}" \
      "${BASE_URL}/api/v1/hosted-calendars"
    ;;

  resend-invite)
    token="$1" cal_id="$2" event_id="$3"
    encoded_cal_id=$(python3 -c "import urllib.parse; print(urllib.parse.quote('hosted:${cal_id}', safe=''))")
    curl -s -X POST \
      -H "Authorization: Bearer ${token}" \
      "${BASE_URL}/api/v1/calendars/${encoded_cal_id}/events/${event_id}/invite"
    ;;

  *)
    echo "Unknown command: $cmd" >&2
    echo "Run without arguments to see usage." >&2
    exit 1
    ;;
esac
