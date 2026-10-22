#!/usr/bin/env bash
set -Eeuo pipefail

die() {
    echo "ERROR: $*" >&2
    exit 1
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"
}

require_jq() {
    need_cmd jq
}

require_gh() {
    need_cmd gh
}

require_git() {
    need_cmd git
}

json_pretty() {
    jq .
}

timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}
