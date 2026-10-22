#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ! -f package.json ]]; then
    echo "no package.json found, skipping"
    exit 0
fi

if [[ -f tsconfig.json ]]; then
    npx --yes tsc --noEmit
fi

if [[ -f .eslintrc.json || -f .eslintrc.js || -f eslint.config.js || -f eslint.config.mjs ]]; then
    npx --yes eslint .
fi
