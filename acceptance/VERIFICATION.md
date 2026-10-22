# V1 Acceptance Verification

Verification baseline: `origin/main` after V1 release. Local scripts are under
`acceptance/scripts/`; they do not write to GitHub and use temporary fixture
repositories where applicable.

| ID | Local executable | Result | Notes |
|---|---|---|---|
| ACC-01 | No | NOT RUN | Requires a disposable repository and real bootstrap permissions. See `run-ci-tests.sh`. |
| ACC-02 | No | NOT RUN | Requires a real Ruleset/PR merge without Code Owner deadlock. |
| ACC-03 | Yes | PASS | `run-scope-guard.sh`: unclassified file returns failure. |
| ACC-04 | Yes | PASS | `run-scope-guard.sh`: two functional scopes return failure. |
| ACC-05 | Yes | PASS | `run-scope-guard.sh`: one functional scope returns success. |
| ACC-06 | Yes | PASS | `run-scope-guard.sh`: functional scope plus unclassified shared path returns failure. |
| ACC-07 | Yes | PASS | `scope-guard` accepts multiple functional scopes when `scope:exception` is present; covered by merged ACC-07 fix. |
| ACC-08 | No | NOT RUN | Requires the digest fixture suite and current GitHub evidence. |
| ACC-09 | No | NOT RUN | Requires the digest blocker fixture suite and current GitHub evidence. |
| ACC-10 | No | NOT RUN | Requires the digest priority fixture suite and current GitHub evidence. |
| ACC-11 | No | NOT RUN | Requires the digest attention fixture suite and current GitHub evidence. |
| ACC-12 | No | NOT RUN | Requires CI branches containing the six language manifests. |
| ACC-13 | No | NOT RUN | Requires real GitHub CI with Swift Package Manager and Xcode variants. |
| ACC-14 | No | NOT RUN | Requires real CI failure, legitimate skip, and cancellation runs. |
| ACC-15 | No | NOT RUN | Requires real workflow mutations and blocking actionlint/zizmor checks. |
| ACC-16 | No | NOT RUN | Requires runtime-only fake secret and real Gitleaks gate. |
| ACC-17 | Yes | PASS | `run-anti-rot.sh`: invalid scope map and missing DECISIONS.md are rejected. Missing script/stub detection is not implemented by the current checker. |
| ACC-18 | Yes | PASS | `run-digest.sh`: fixture suite plus real digest; 279 bytes and 20 lines in Markdown output. |
| ACC-19 | No | NOT RUN | Requires a disposable Copier-generated repository and update operation. |
| ACC-20 | No | NOT RUN | Requires a controlled old-`gh` capability check. |
| ACC-21 | No | NOT RUN | Requires rerunning bootstrap against an already initialized repository. |
| ACC-22 | No | NOT RUN | Requires real GitHub Ruleset capability degradation. |
| ACC-23 | No | NOT RUN | Requires real post-merge label-sync workflow evidence. |

## Local Commands

```bash
acceptance/scripts/run-all.sh
acceptance/scripts/run-scope-guard.sh
acceptance/scripts/run-anti-rot.sh
acceptance/scripts/run-digest.sh
acceptance/scripts/run-ci-tests.sh
```

`run-all.sh` executes all currently automatable local acceptance cases and
prints the remaining GitHub/disposable-repository cases as `NOT RUN`.
`run-scope-guard.sh` is expected to pass all local scope cases.
`run-anti-rot.sh` restores all temporary fixtures automatically through its
trap. `run-digest.sh` performs read-only GitHub access for the real repository.

## CI Verification Instructions

Use a disposable branch/repository derived from the current `main` and record
the commit SHA, workflow URL, expected result, actual result, and cleanup in
this report. Do not claim a GitHub acceptance case passed from a local mock.

- ACC-01: run bootstrap against a private disposable repository with the
  required repository permissions; verify labels, Ruleset, CI, branch
  auto-delete, and Copier metadata.
- ACC-02: create and merge a PR under the configured single-owner Ruleset;
  verify that Code Owner self-approval is not required.
- ACC-12: create separate branches with each supported language manifest and
  verify only the matching checker runs while other checkers skip.
- ACC-13: run SwiftPM and Xcode fixture branches; verify the configured Swift
  path runs and unsupported Xcode configuration skips legitimately.
- ACC-14: create CI runs with a required failure, legitimate detection skip,
  and cancellation; verify only success/skipped pass the gate.
- ACC-15: use temporary workflow mutations for an unpinned action and invalid
  syntax; verify zizmor/actionlint block the gate, then remove the mutation.
- ACC-16: create a fake secret only during the runner job; verify Gitleaks
  fails and confirm no secret is committed.
- ACC-19: generate a disposable repository with Copier, update the template,
  and verify infrastructure changes do not overwrite project-specific code.
- ACC-21: rerun bootstrap in the initialized repository; verify no duplicate
  or destructive operation occurs.
- ACC-22: run against a repository/API capability where Ruleset support is
  unavailable; verify unsupported is a warning/skip while missing required
  properties fail.
- ACC-23: after FASE 3 is merged, push a controlled `.github/labels.yml`
  change to `main`; verify canonical labels synchronize and an extra label is
  retained.

## Post-V1 CI Testing

These cases require a disposable repository derived from the released
template. Do not run destructive bootstrap operations against this repository.
Use a GitHub account with repository administration rights, an authenticated
`gh`, Copier, and the local tools required by the generated repository.

Common setup:

```bash
export TEST_REPO="owner/agent-template-acceptance-$(date +%Y%m%d%H%M%S)"
copier copy gh:piergiorgio1999/agent-template "/tmp/${TEST_REPO##*/}"
cd "/tmp/${TEST_REPO##*/}"
git config user.name "Acceptance Runner"
git config user.email "acceptance@example.invalid"
```

After each test, record the repository, commit SHA, workflow URL, expected and
actual result, then delete the disposable repository through the GitHub UI or
`gh repo delete "$TEST_REPO" --yes` only after preserving the evidence.

### ACC-01 Bootstrap end-to-end

Run `./tools/bootstrap/bootstrap` in the generated directory. Verify the
private repository, initial `main` push, canonical labels, Ruleset, first CI
run, branch auto-delete setting, and Copier metadata. Record the first CI URL
from `gh run list --repo "$TEST_REPO" --branch main --limit 1 --json url`.

### ACC-02 Single-owner workflow

Create a one-scope change, open a PR, and verify the Ruleset does not require
Code Owner self-approval. Merge it only in the disposable repository and
record the merge and resulting CI run.

### ACC-12 Language detection

Create six independent branches, each containing exactly one of `go.mod`,
`pyproject.toml`, `Cargo.toml`, `package.json`/`tsconfig.json`,
`Package.swift`, or a shell script. Push each branch and verify the matching
checker runs while unrelated language steps are explicitly skipped.

### ACC-13 Swift/Xcode

Use one SwiftPM fixture and two Xcode fixtures: no Xcode configuration and a
valid configuration. Verify `swift test` runs for SwiftPM, the unsupported
configuration skips legitimately, and the valid configuration runs.

### ACC-14 CI Gate

Use temporary disposable branches to produce one required failure, one
legitimate detection skip, and one cancellation. Verify `gate` passes only for
success/legitimate skip and fails for failure/cancellation.

### ACC-15 Actions security

On disposable branches, introduce one mutable action reference and one invalid
workflow syntax error. Verify zizmor and actionlint fail respectively, then
remove both temporary changes.

### ACC-16 Runtime secret detection

Create a fake secret only during a runner step, never in a commit. Verify
Gitleaks fails and the gate fails; confirm `git log` and the pushed tree contain
no secret.

### ACC-19 Copier update

Generate a disposable project with Copier, add project-specific code, run
`copier update` against the released template, and verify infrastructure
updates without overwriting that code. Record the before/after diff.

### ACC-21 Bootstrap re-run

Run bootstrap once successfully, then run it again against the same generated
directory and repository. Verify it fails safely with an existing-state message
and performs no deletion, duplicate repository creation, or destructive reset.

### ACC-22 Ruleset degradation

Run against a disposable repository/API capability where Rulesets are
unsupported. Verify the tool reports `WARNING` and skips only that optional
operation; if an indispensable Ruleset property is unavailable, verify a clear
failure instead.

## Gaps

- `agent-config-check` validates core files and JSON/version consistency but
  does not detect every missing script or TODO stub listed by ACC-17.
- CI-only cases still need real GitHub evidence; local fixtures are not a
  substitute for Ruleset, Actions, Gitleaks, Copier, or workflow behavior.

## Proposals

PROPOSTA: extend `scope-guard` with a deterministic, CI-provided
`scope:exception` signal / label input and add acceptance coverage for it;
cost and exact interface should be reviewed in FASE 5 before implementation.

PROPOSTA: expand `agent-config-check` anti-rot assertions to cover required
script existence and rejection of known TODO stubs; defer until the FASE 5
audit confirms the canonical file set.

## Post-V1 Proposals

- **P-01 — Checker self-test:** evaluate the saved
  `/tmp/checker-selftest-wip.patch` and implement it in a dedicated PR only if
  the audit confirms a concrete reliability benefit.
- **P-02 — Dependabot grouping:** evaluate weekly grouped rules by ecosystem
  before changing Dependabot configuration.
- **P-03 — Retire duplicate validators:** decide whether the audited
  placeholder validators should be removed or consolidated into one canonical
  validation command.
- **P-04 — `.template/` role:** decide whether `.template/` is distributed
  metadata or historical scaffolding before changing Copier output.
- **P-05 — Live acceptance harness:** consider a controlled disposable-repo
  harness for repeatable CI-only acceptance evidence; do not run it against
  production repositories.
