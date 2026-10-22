#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ! -f go.mod ]]; then
    echo "no go.mod found, skipping"
    exit 0
fi

go vet ./...

unformatted="$(gofmt -l .)"
if [[ -n "$unformatted" ]]; then
    echo "gofmt: files not formatted:"
    echo "$unformatted"
    exit 1
fi
