#!/usr/bin/env bash
set -Eeuo pipefail

if ! command -v shellcheck >/dev/null 2>&1; then
    echo "shellcheck not installed, skipping"
    exit 0
fi

files=""
while IFS= read -r f; do
    files="$files
$f"
done < <(find . -type f -name "*.sh" -not -path "./.git/*")
files="$(echo "$files" | sed '/^$/d')"

if [[ -z "$files" ]]; then
    echo "no shell scripts found"
    exit 0
fi

echo "$files" | xargs shellcheck
