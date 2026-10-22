#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
checker="$ROOT/.github/ci-gate/check-linking"

expect_pass() {
    PR_AUTHOR_LOGIN="$1" PR_CLOSING_REFERENCES_JSON="$2" "$checker" >/dev/null
}

expect_fail() {
    if PR_AUTHOR_LOGIN="$1" PR_CLOSING_REFERENCES_JSON="$2" "$checker" >/dev/null 2>&1; then
        echo "expected linking failure" >&2
        exit 1
    fi
}

expect_pass 'human' '[{"number":103}]'
expect_fail 'human' '[]'
expect_fail 'human' '[{"number":103},{"number":104}]'
expect_pass 'dependabot[bot]' '[]'
expect_fail 'renovate[bot]' '[]'

echo "linking matrix: PASS"
