#!/usr/bin/env bash
set -Eeuo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURES="$DIR/tests/fixtures"

bash -n "$DIR/project-status"
jq empty "$FIXTURES/issues.json" "$FIXTURES/prs.json"

json="$(PROJECT_STATUS_MOCK_DIR="$FIXTURES" PROJECT_STATUS_MOCK_REPOSITORY="fixture/repository" "$DIR/project-status" json)"

jq -e '
  .repository == "fixture/repository" and
  (.done | index("#1 Closed work")) and
  (.current | index("#2 In progress")) and
  (.current_prs[0].pr == "#10") and
  (.current_prs[0].diagnosis == "PASS: checks complete") and
  ([.current_prs[] | select(.pr == "#20") | .diagnosis] | .[0] == "WAIT: external check incomplete") and
  ((.current | index("#6 Blocked issue")) | not) and
  ((.current | index("#7 Needs attention")) | not) and
  (.blocked | index("#3 Blocked work")) and
  (.blocked | index("#6 Blocked issue")) and
  (.next[0] == "#4 Next P2") and
  ((.next | index("#7 Needs attention")) | not) and
  (.attention | index("#7 Needs attention")) and
  (.attention | index("PR #11 Conflicting issue 5")) and
  (.attention | index("PR #13 Attention issue 2")) and
  ((.attention | index("PR #12 Blocked issue 6")) | not) and
  (.progress.features[0].closed == 1) and
  (.progress.features[0].total == 2)
' <<<"$json" >/dev/null

diagnose_json="$(PROJECT_STATUS_MOCK_DIR="$FIXTURES" "$DIR/project-status" diagnose json)"
jq -e '
  (.ci_diagnostics | length) == 2 and
  .ci_diagnostics[0].pr == 11 and
  .ci_diagnostics[0].job == "security" and
  .ci_diagnostics[0].step == "Zizmor" and
  .ci_diagnostics[0].location == "src/workflow.yml:42:7" and
  .ci_diagnostics[1].location == null
' <<<"$diagnose_json" >/dev/null

text="$(PROJECT_STATUS_MOCK_DIR="$FIXTURES" "$DIR/project-status" md)"
diagnose_text="$(PROJECT_STATUS_MOCK_DIR="$FIXTURES" "$DIR/project-status" diagnose md)"
grep -Fq '## CI Diagnostics' <<<"$diagnose_text"
grep -Fq 'src/workflow.yml:42:7' <<<"$diagnose_text"
bytes="$(printf '%s' "$text" | wc -c | tr -d ' ')"
lines="$(printf '%s\n' "$text" | wc -l | tr -d ' ')"
(( bytes <= 8192 ))
(( lines <= 100 ))

long_fixture="$(mktemp -d)"
jq -n '[range(1;141) | {number: ., title: ("é issue " + tostring), state: "OPEN", labels: [], milestone: null, subIssues: [], blockedBy: [], blocking: []}]' > "$long_fixture/issues.json"
printf '%s\n' '[]' > "$long_fixture/prs.json"
long_text="$(PROJECT_STATUS_MOCK_DIR="$long_fixture" "$DIR/project-status" md)"
long_bytes="$(printf '%s' "$long_text" | wc -c | tr -d ' ')"
long_lines="$(printf '%s\n' "$long_text" | wc -l | tr -d ' ')"
(( long_bytes <= 8192 ))
(( long_lines <= 100 ))
grep -Fq '… truncated' <<<"$long_text"
grep -Fq '## Current PR' <<<"$text"
printf '%s' "$long_text" | iconv -f UTF-8 -t UTF-8 >/dev/null
rm -rf "$long_fixture"

echo "project-status tests: PASS"
