#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GUARD="$ROOT/tools/scope-guard/scope-guard"
pass=0
fail=0

make_repo() {
    local dir
    dir="$(mktemp -d)"
    git -C "$dir" init -q -b main
    git -C "$dir" config user.email test@example.com
    git -C "$dir" config user.name acceptance
    mkdir -p "$dir/tools/lib" "$dir/tools/scope-guard"
    cp "$ROOT/scope-map.json" "$dir/scope-map.json"
    cp "$ROOT/tools/lib/common.sh" "$dir/tools/lib/common.sh"
    cp "$GUARD" "$dir/tools/scope-guard/scope-guard"
    printf '%s\n' '# decisions' > "$dir/DECISIONS.md"
    git -C "$dir" add -A
    git -C "$dir" commit -q -m base
    git -C "$dir" switch -q -c feature
    printf '%s\n' "$dir"
}

run_case() {
    local id="$1" expected="$2" description="$3" dir actual=0
    dir="$(make_repo)"
    mkdir -p "$dir/checks/python" "$dir/tools/scope-guard"
    case "$id" in
        ACC-03) printf x > "$dir/unclassified.txt" ;;
        ACC-04) printf x > "$dir/tools/scope-guard/change"; printf y > "$dir/checks/python/change" ;;
        ACC-05) printf x > "$dir/tools/scope-guard/change" ;;
        ACC-06) mkdir -p "$dir/shared/core"; printf x > "$dir/tools/scope-guard/change"; printf y > "$dir/shared/core/change" ;;
        ACC-07) printf x > "$dir/tools/scope-guard/change"; printf y > "$dir/checks/python/change" ;;
    esac
    git -C "$dir" add -A
    git -C "$dir" commit -q -m "$id"
    if [[ "$id" == "ACC-07" ]]; then
        (cd "$dir" && SCOPE_EXCEPTION_LABELS="scope:exception" ./tools/scope-guard/scope-guard main) >"$dir/output" 2>&1 || actual=$?
    else
        (cd "$dir" && ./tools/scope-guard/scope-guard main) >"$dir/output" 2>&1 || actual=$?
    fi
    if [[ "$actual" == "$expected" ]]; then
        echo "PASS $id: $description"
        pass=$((pass + 1))
    else
        echo "FAIL $id: $description (expected exit $expected, got $actual)"
        cat "$dir/output"
        fail=$((fail + 1))
    fi
    rm -rf "$dir"
}

run_case ACC-03 1 "unclassified file fails"
run_case ACC-04 1 "two functional scopes fail"
run_case ACC-05 0 "one functional scope passes"
run_case ACC-06 1 "shared without exception fails"
run_case ACC-07 0 "two functional scopes with scope:exception pass"

echo "scope guard: $pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
