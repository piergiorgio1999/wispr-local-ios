# Architectural Decisions

Le decisioni permanenti vivono qui.

Le Issue devono referenziare le decisioni.

Non duplicare la rationale nelle Issue.

## 2026-08-09 — Attivazione anticipata dei checker per linguaggio

I checker in `checks/*/check.sh` erano dichiarati "Dormant" /
"Implementation is intentionally deferred". Decisione: attivarli ora
invece di aspettare, cablando tool OSS standard per linguaggio
(shellcheck, go vet + gofmt, ruff, cargo clippy, tsc + eslint, swift
build) e rendendo reali i job `detect` (rilevamento manifest) e
`security` (gitleaks, actionlint, zizmor) in `.github/workflows/ci.yml`.

Ogni check resta un no-op (exit 0) se il manifest del linguaggio non
è presente, quindi è sicuro anche su repository generati che non
usano tutti i linguaggi.

## 2026-08-09 — zizmor advisory temporaneo durante la remediation del debito

L'attivazione di zizmor (decisione precedente) ha reso rosso `main`:
43 finding preesistenti nei workflow GitHub esistenti (15 high, 10
medium, 4 low — es. action non pinnate a hash, permessi troppo ampi,
`persist-credentials` non disattivato), non causati dal lavoro che ha
attivato il check ma debito preesistente rivelato per la prima volta.

Decisione: portare `main` verde con una modifica minima e temporanea
allo step `Zizmor` in `.github/workflows/ci.yml` — aggiunta di
`continue-on-error: true` solo su quello step. zizmor resta attivo e
visibile nei log (nessun finding viene ignorato, filtrato o
soppresso); diventa temporaneamente advisory (non blocca il job
`security` né il gate) fino al completamento della remediation dei 43
finding preesistenti, tracciata in issue di follow-up. I workflow che
generano i finding non vengono modificati in questa decisione — la
remediation è un lavoro separato, a scope singolo (`github`).

Al termine della remediation, rimuovere `continue-on-error: true` dallo
step `Zizmor` e ripristinare zizmor come blocking.

## 2026-08-09 — Remediation completata, zizmor torna blocking

Remediation dei 43 finding preesistenti (issue #8) completata in tutti
i workflow (`.github/workflows/ci.yml`, `label-sync.yml`,
`checker-selftest.yml`) e in `.github/dependabot.yml`: azioni pinnate
a hash di commit (con commento `# vX`), `permissions` minimi espliciti
per job, `persist-credentials: false` su ogni `actions/checkout`,
rimossa l'interpolazione diretta di `github.base_ref` in uno `run:`
(passata via `env:`), aggiunto `cooldown.default-days: 7` alle regole
Dependabot. `zizmor .` risulta pulito (0 finding).

Rimosso `continue-on-error: true` dallo step `Zizmor`: torna blocking
come da piano di rientro della decisione precedente.

## 2026-08-10 — Metodo di merge scelto dal Merge Advisor

Gli agenti usano il metodo indicato dal commento aggiornabile di `PR
Verification` per l'head SHA corrente: squash, rebase oppure merge commit.
`WAIT` impedisce il merge fino alla risoluzione del blocco. La scelta resta
diagnostica e non introduce un secondo required check: `CI Gate` rimane
l'unico check obbligatorio previsto da SPEC-V1.
