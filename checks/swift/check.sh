#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ! -f Package.swift ]]; then
    echo "no Package.swift found, skipping"
    exit 0
fi

swift test

if command -v swiftlint >/dev/null 2>&1; then
    swiftlint
fi
