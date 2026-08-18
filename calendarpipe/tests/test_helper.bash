# Shared setup for bats tests.
# Loaded via `load ../test_helper` from each .bats file.

PROJECT_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
SCRIPT="${PROJECT_ROOT}/scripts/calendarpipe.sh"
TOKEN="test-token-xxx"

# ---------------------------------------------------------------------------
# Mock-curl lifecycle
#
# Defined here rather than in each .bats file so they are opt-OUT. A unit file
# that forgot them would run against the real curl, with the developer's real
# ~/.config/calendarpipe token — which is exactly what setup_mock_curl exists to
# prevent. Integration tests override setup/teardown to reach the network.
# ---------------------------------------------------------------------------

setup_mock_curl() {
  export MOCK_CURL_LOG
  MOCK_CURL_LOG="$(mktemp -t calendarpipe-curl.XXXXXX)"
  export PATH="${PROJECT_ROOT}/tests/mocks:${PATH}"
  export CALENDARPIPE_API_KEY="$TOKEN"

  # Point config lookup at an empty directory so a developer's real
  # ~/.config/calendarpipe/config.json can never satisfy a test.
  FAKE_XDG="$(mktemp -d -t calendarpipe-xdg.XXXXXX)"
  export XDG_CONFIG_HOME="$FAKE_XDG"
}

teardown_mock_curl() {
  [ -n "${MOCK_CURL_LOG:-}" ] && rm -f "$MOCK_CURL_LOG"
  [ -n "${FAKE_XDG:-}" ] && rm -rf "$FAKE_XDG"
  # The wrapper migrates this into place on startup; never leave one behind.
  rm -f "${PROJECT_ROOT}/config.json"
  unset CALENDARPIPE_API_KEY MOCK_CURL_RESPONSE
}

setup() { setup_mock_curl; }
teardown() { teardown_mock_curl; }

# Write a config.json into the fake XDG home, for tests that exercise the
# file-based key lookup.
write_config() {
  mkdir -p "${XDG_CONFIG_HOME}/calendarpipe"
  printf '%s' "$1" > "${XDG_CONFIG_HOME}/calendarpipe/config.json"
}

# Write a config.json where pre-2.0 installs kept it — inside the skill dir.
write_legacy_config() {
  printf '%s' "$1" > "${PROJECT_ROOT}/config.json"
}

config_path() { echo "${XDG_CONFIG_HOME}/calendarpipe/config.json"; }

# Octal permission bits, GNU or BSD. GNU first: it accepts -c and BSD rejects
# it, whereas BSD-first fails open on Linux — `stat -f` there prints filesystem
# status and exits 0, so a `||` fallback never runs and the caller compares
# against the wrong string entirely.
file_mode() {
  stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"
}

# ---------------------------------------------------------------------------
# Assertion helpers — parse the logged curl argv
# ---------------------------------------------------------------------------

# Full argv, one arg per line
curl_log() { cat "$MOCK_CURL_LOG"; }

# Last arg passed to curl is always the URL
curl_url() { tail -n 1 "$MOCK_CURL_LOG"; }

# HTTP method — value after -X, or "GET" if absent
curl_method() {
  local m
  m=$(awk 'prev=="-X"{print; exit} {prev=$0}' "$MOCK_CURL_LOG")
  echo "${m:-GET}"
}

# Request body — value after -d, or empty if absent
curl_body() {
  awk 'prev=="-d"{print; exit} {prev=$0}' "$MOCK_CURL_LOG"
}

# Find a header by its prefix, e.g. curl_header "Authorization:"
curl_header() {
  local prefix="$1"
  awk -v p="$prefix" 'prev=="-H" && index($0,p)==1 {print; exit} {prev=$0}' "$MOCK_CURL_LOG"
}
