#!/usr/bin/env bash
# Test runner — unit by default, add --integration to also hit the real API.
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v bats >/dev/null 2>&1; then
  echo "bats-core not installed — run: brew install bats-core" >&2
  exit 1
fi

if [ "${1:-}" = "--integration" ] || [ "${1:-}" = "-i" ]; then
  bats unit integration
elif [ "${1:-}" = "--all" ]; then
  bats unit integration
else
  bats unit
fi
