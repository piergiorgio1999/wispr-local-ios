#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ! -f pyproject.toml && ! -f setup.py && ! -f requirements.txt ]]; then
    echo "no python manifest found, skipping"
    exit 0
fi

if ! command -v ruff >/dev/null 2>&1; then
    echo "ruff not installed, skipping"
    exit 0
fi

ruff check .
