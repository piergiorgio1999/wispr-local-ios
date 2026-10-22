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
  ([.current_prs[] | select(.pr == "#21") | .diagnosis] | .[0] == "WAIT: structured dependency is still open") and
  ([.current_prs[] | select(.pr == "#21") | .issue] | .[0] == "#21") and
  ([.current_prs[] | select(.pr == "#21") | .dependencies[0].number] | .[0] == 10) and
  ([.current_prs[] | select(.pr == "#21") | .dependencies[0].source] | .[0] == "Issue #21 blocked by Issue #2") and
  ([.current_prs[] | select(.pr == "#22") | .diagnosis] | .[0] == "WAIT: no checks visible") and
  ([.current_prs[] | select(.pr == "#22") | .issue] | .[0] == null) and
  ([.current_prs[] | .pr] | length == (unique | length)) and
  ((.current | index("#6 Blocked issue")) | not) and
  ((.current | index("#7 Needs attention")) | not) and
  (.blocked | index("#3 Blocked work")) and
  (.blocked | index("#6 Blocked issue")) and
  (.next[0] == "#4 Next P2") and
  ((.next | index("#7 Needs attention")) | not) and
  (.attention | index("#7 Needs attention")) and
  (.attention | index("PR #11 Conflicting issue 5")) and
  (.attention | index("PR #13 Attention issue 2")) and
  (.attention | index("PR #14 Action required")) and
  ((.attention | index("PR #12 Blocked issue 6")) | not) and
  (.progress.features[0].closed == 1) and
  (.progress.features[0].total == 2)
' <<<"$json" >/dev/null

diagnose_json="$(PROJECT_STATUS_MOCK_DIR="$FIXTURES" "$DIR/project-status" diagnose --all json)"
jq -e '
  (.ci_diagnostics | length) == 2 and
  .ci_diagnostics[0].pr == 11 and
  .ci_diagnostics[0].job == "security" and
  .ci_diagnostics[0].step == "Zizmor" and
  .ci_diagnostics[0].location == "src/workflow.yml:42:7" and
  .ci_diagnostics[1].location == null
' <<<"$diagnose_json" >/dev/null

live_json="$(PATH="$DIR/tests/fake-bin:$PATH" "$DIR/project-status" diagnose --all json)"
live_text="$(PATH="$DIR/tests/fake-bin:$PATH" "$DIR/project-status" diagnose --all md)"
jq -e '
  ([.current_prs[] | select(.pr == "#130") | .diagnosis][0] == "PASS: checks complete") and
  ([.current_prs[] | select(.pr == "#130") | .checks[]] == ["CI Gate 🟢 success"]) and
  ([.ci_diagnostics[] | select(.pr == 130)] | length == 0) and
  ([.ci_diagnostics[] | select(.pr == 131)] | length == 1) and
  ([.ci_diagnostics[] | select(.pr == 131)][0].error | contains("error[dangerous-triggers]")) and
  ([.ci_diagnostics[] | select(.pr == 131)][0].error | contains("pull_request_target")) and
  ([.ci_diagnostics[] | select(.pr == 131)][0].error | contains("Process completed with exit code") | not) and
  ([.ci_diagnostics[] | select(.pr == 131)][0].evidence | length > 1) and
  ([.ci_diagnostics[] | select(.pr == 131)][0].affected_paths == [".github/workflows/example.yml"]) and
  ([.ci_diagnostics[] | select(.pr == 131)][0].location == "./.github/workflows/example.yml:3:1") and
  ([.ci_diagnostics[] | select(.pr == 131)][0].escalation | startswith("INSUFFICIENT:")) and
  ([.current_prs[] | select(.pr == "#131")][0].dependencies[0].number == 130) and
  ([.current_prs[] | select(.pr == "#131")][0].dependencies[0].source == "Issue #31 blocked by Issue #30") and
  ([.current_prs[] | select(.pr == "#131")][0].related[0].target == 130) and
  ([.current_prs[] | select(.pr == "#131")][0].diagnosis == "WAIT: structured dependency is still open") and
  ([.current_prs[] | select(.pr == "#132")][0].issue == null) and
  ([.current_prs[] | select(.pr == "#132")][0].declared_closing_refs == [999]) and
  ([.current_prs[] | select(.pr == "#132")][0].recognized_closing_refs == []) and
  ([.current_prs[] | select(.pr == "#132")][0].related == []) and
  ([.ci_diagnostics[] | select(.pr == 132)] | length == 1) and
  ([.ci_diagnostics[] | select(.pr == 132)][0].error == "linking: exactly one closing issue reference is required") and
  ([.ci_diagnostics[] | select(.pr == 132)][0].escalation == "FIX: address the reported failure")
' <<<"$live_json" >/dev/null

text="$(PROJECT_STATUS_MOCK_DIR="$FIXTURES" "$DIR/project-status" md)"
diagnose_text="$(PROJECT_STATUS_MOCK_DIR="$FIXTURES" "$DIR/project-status" diagnose --all md)"
targeted_text="$(PROJECT_STATUS_MOCK_DIR="$FIXTURES" "$DIR/project-status" diagnose --pr 11 md)"
grep -Fq '## CI Diagnostics' <<<"$diagnose_text"
grep -Fq 'src/workflow.yml:42:7' <<<"$diagnose_text"
grep -Fq '#11 Conflicting issue 5' <<<"$targeted_text"
if grep -Fq '#10 Implements issue 2' <<<"$targeted_text"; then
  echo "targeted digest unexpectedly included an unselected PR" >&2
  exit 1
fi
grep -Fq 'DEPENDS-ON: PR #10 [OPEN] — Issue #21 blocked by Issue #2' <<<"$text"
grep -Fq '#22 Unlinked PR (no closing Issue)' <<<"$text"
grep -Fq 'RELATED: PR #130 [OPEN] — modifies failure path .github/workflows/example.yml' <<<"$live_text"
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
