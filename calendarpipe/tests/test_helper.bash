# Shared setup for bats tests.
# Loaded via `load ../test_helper` from each .bats file.

PROJECT_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
SCRIPT="${PROJECT_ROOT}/scripts/calendarpipe.sh"
TOKEN="test-token-xxx"

# ---------------------------------------------------------------------------
# Mock-curl lifecycle (unit tests only — integration tests skip this)
# ---------------------------------------------------------------------------

setup_mock_curl() {
  export MOCK_CURL_LOG
  MOCK_CURL_LOG="$(mktemp -t calendarpipe-curl.XXXXXX)"
  export PATH="${PROJECT_ROOT}/tests/mocks:${PATH}"
}

teardown_mock_curl() {
  [ -n "${MOCK_CURL_LOG:-}" ] && rm -f "$MOCK_CURL_LOG"
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
