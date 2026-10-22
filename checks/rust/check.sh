#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ! -f Cargo.toml ]]; then
    echo "no Cargo.toml found, skipping"
    exit 0
fi

if ! command -v cargo >/dev/null 2>&1; then
    echo "cargo not installed, skipping"
    exit 0
fi

cargo clippy --all-targets --all-features -- -D warnings
