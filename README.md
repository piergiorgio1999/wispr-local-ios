# Agent-Ready Template

Template Copier per repository GitHub-native orientati agli agenti di coding.
Fornisce governance, scope isolation, CI deterministica, controlli di
sicurezza e un digest read-only dello stato GitHub.

La specifica vincolante è [`SPEC-V1.md`](SPEC-V1.md). Le istruzioni operative
per gli agenti sono in [`AGENTS.md`](AGENTS.md); le decisioni permanenti sono in
[`DECISIONS.md`](DECISIONS.md).

## Prerequisiti

- Git
- GitHub CLI (`gh`) autenticato con permessi per creare e amministrare il
  repository destinazione
- Copier (`copier`)
- `jq`, `shellcheck` e `actionlint`
- accesso GitHub al repository template e al nuovo repository

Il bootstrap verifica anche che la versione di `gh` supporti il campo
`closingIssuesReferences`.

## Quick Start

```bash
copier copy gh:piergiorgio1999/agent-template /path/to/tuo-progetto
cd /path/to/tuo-progetto
./tools/bootstrap/bootstrap
```

Il bootstrap è fail-safe: rifiuta directory già inizializzate, repository
GitHub esistenti e configurazioni incomplete. Non esegue cancellazioni o
rollback distruttivi.

Variabili opzionali:

```bash
BOOTSTRAP_GITHUB_OWNER=owner \
BOOTSTRAP_REPO_NAME=repository \
BOOTSTRAP_VISIBILITY=private \
./tools/bootstrap/bootstrap
```

## Struttura

- `.github/`: workflow CI, Issue Forms, PR template, CODEOWNERS, label e
  configurazione Dependabot/Ruleset.
- `tools/`: i quattro tool custom e librerie condivise.
- `checks/`: checker per Shell, Go, Python, Rust, TypeScript e Swift.
- `acceptance/`: contratti ACC-01..29 e report di verifica.
- `template-fixtures/`: manifest minimi per testare il rilevamento dei linguaggi.
- `docs/`: architettura, bootstrap, validazione e release.
- `config/`, `schemas/`, `.template/`, `release/`: metadati e documentazione
  ereditati; il loro uso è tracciato in [`AUDIT.md`](AUDIT.md).

## Tool Custom

- [`scope-guard`](tools/scope-guard/scope-guard): verifica che una PR tocchi
  un solo functional scope secondo `scope-map.json`; supporta
  `scope:exception` per il caso previsto dalla SPEC.
- [`agent-config-check`](tools/agent-config-check/agent-config-check): verifica
  file fondamentali, JSON della scope map e coerenza della versione template.
- [`project-status`](tools/project-status/project-status): produce un digest
  JSON o Markdown read-only derivato da GitHub tramite `gh` e `jq`.
- [`bootstrap`](tools/bootstrap/bootstrap): crea in modo fail-safe un nuovo
  repository, pubblica il commit iniziale e applica il Ruleset.

## CI

La CI esegue, nell’ordine previsto dal contratto:

1. anti-rot e scope guard;
2. rilevamento dei linguaggi e checker pertinenti;
3. `gitleaks`, `actionlint` e `zizmor`;
4. gate unico blocking.

I checker sono no-op quando il relativo manifest non è presente. Le action
third-party sono fissate a commit SHA e i job usano permessi minimi.

Il workflow [`label-sync.yml`](.github/workflows/label-sync.yml) sincronizza
le label canoniche senza eliminare label extra.

## Aggiornare il Template

Dal repository generato:

```bash
copier update
```

Rivedi sempre il diff prima del commit. Il codice project-specific deve restare
separato dagli aggiornamenti dell’infrastruttura del template; verifica i
conflitti seguendo [`SPEC-V1.md`](SPEC-V1.md).

## Verifica Acceptance

I 29 casi sono elencati in [`acceptance/cases/`](acceptance/cases/) e il report
operativo è [`acceptance/VERIFICATION.md`](acceptance/VERIFICATION.md).
I test locali possono essere eseguiti con:

```bash
acceptance/scripts/run-scope-guard.sh
acceptance/scripts/run-anti-rot.sh
acceptance/scripts/run-digest.sh
```

I casi che richiedono GitHub Actions, Ruleset o un repository derivato devono
essere eseguiti su una risorsa disposable e non simulati localmente.

## Troubleshooting

### `missing required command: copier`

Installa Copier e ripeti il comando. Il bootstrap non prosegue se manca un
prerequisito.

### `refusing to run: .git already exists`

Il bootstrap è pensato per una directory appena generata da Copier. Usa una
directory nuova; non elimina mai un repository esistente.

### `closingIssuesReferences` non supportato

Aggiorna GitHub CLI e verifica con:

```bash
gh version
gh pr list --repo piergiorgio1999/agent-template --limit 1 \
  --json closingIssuesReferences
```

### `scope-guard: multiple scopes touched`

Controlla i file della PR rispetto a [`scope-map.json`](scope-map.json). Una
PR deve avere un solo scope, salvo la label `scope:exception` quando la
deroga è realmente necessaria.

### CI rossa su un checker

Esegui prima il checker locale pertinente da `checks/`, poi controlla i log del
job GitHub. Non aggiungere bypass: la CI è intenzionalmente blocking.

### Digest vuoto o non disponibile

Verifica autenticazione e accesso di `gh`, quindi esegui:

```bash
tools/project-status/project-status md
```

Il digest è read-only e non è una fonte di verità persistente.
