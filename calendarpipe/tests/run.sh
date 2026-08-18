#!/usr/bin/env bash
# Test runner — unit by default, add --integration to also hit the real API.
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v bats >/dev/null 2>&1; then
  echo "bats-core not installed — run: brew install bats-core" >&2
  exit 1
fi

case "${1:-}" in
  --integration | -i | --all) bats unit integration ;;
  *) bats unit ;;
esac
