# SPEC-V1.1 — Agent-Ready Template (CONGELATA)

Questo file è IL CONTRATTO vincolante.
In caso di divergenza con qualsiasi altro file del repo (docs, config/,
acceptance/cases/, .template/), SPEC-V1.md PREVALE.
Non modificare senza approvazione esplicita dell'architetto.

## 1. VINCOLI ASSOLUTI
1. GitHub = unica source of truth persistente
2. Profilo MCP opzionale = adapter locale stdio selezionato da Copier; `standalone` resta il default. Nessun servizio remoto, webhook o pubblicazione automatica.
3. Project Status Digest = funzione read-only derivata; MAI committato, MAI editabile, MAI source of truth
4. Runtime tool custom = Bash + jq + gh. Il solo adapter MCP opzionale usa Node.js e l'SDK MCP ufficiale pinnato. VIETATI: yq, PyYAML, parser YAML custom, Python per parsing
5. scope-map.json = UNICA fonte classificazione path; overlap: first-match-wins (ordine chiavi); OGNI file classificato (nessun unclassified)
6. dorny/paths-filter = SOLO changed-files detection e language/checker activation; NON duplica la scope map; niente YAML intermedi
7. Gitleaks = CI scanner segreti universale; .gitleaks.toml esclude template-fixtures/**; scanning nativo = strato opzionale; secret di test = runtime-only, MAI committati
8. single_owner = default true → CODEOWNERS esiste ma il Ruleset NON richiede Code Owner approval (anti-deadlock)
9. Digest text ≤ 8 KiB AND ≤ 100 righe (indipendente da tokenizer)
10. Third-party actions = full commit SHA con commento "# vX.Y.Z"; mai tag mutabili
11. CI Gate = unico required check; if: always(); accetta success + skipped legittimi (da detection outputs espliciti); fallisce su failure/cancelled/unexpected skip
12. Bootstrap = fail-safe (fail if exists; zero operazioni distruttive); capability check concreto sui permessi (NO admin:org preventivo); gh version check su closingIssuesReferences con FAIL chiaro se incompatibile

## 2. FILE VIETATI
Mai creare: PROJECT_STATE.json, ROADMAP.md, STATUS.md, TASKS.md, PLAN.md

## 3. FUORI DALLA V1
NON implementare: Projects v2, Harden Runner, CodeQL obbligatorio, commit signing, GitHub App, composite actions/reusable workflows, cache CI universale, custom log framework, GraphQL custom, widget write-back. Dependency Review = modulo opzionale solo se il piano lo supporta, mai required.

## 4. STRUTTURA TARGET V1
README AGENTS CLAUDE DECISIONS SECURITY | copier.yml scope-map.json |
.github/(CODEOWNERS dependabot.yml labels.yml pull_request_template.md ruleset.json ISSUE_TEMPLATE/ workflows/) |
tools/(scope-guard agent-config-check project-status bootstrap) | checks/ | template-fixtures/
Profilo MCP opzionale: mcp/(server.mjs package.json package-lock.json README.md).

NOTA AUDIT: le directory extra ereditate (config/, schemas/, scripts/, .template/, release/, tools/validate/) NON vanno cancellate ora. Audit DOPO che ACC-01..23 sono verdi; rimuovere/consolidare solo ciò che resta inutilizzato.

## 5. SOURCE OF TRUTH
istruzioni agenti→AGENTS.md | decisioni→DECISIONS.md | task→Issues | scomposizione→sub-issues | blocker→dependencies | fase→Milestone | priorità→labels priority:* | in progress→Issue open+PR open | completamento→closed/merged | verifica→Checks | cronologia→Git | stato sintetico→Digest derivato

## 6. TOOL CUSTOM (esattamente 4)
scope-guard | agent-config-check | project-status (digestor REALE: gh --json, feature detection con fallback label, read-only) | bootstrap

L'adapter MCP non introduce un quinto tool autorevole: espone esclusivamente i
quattro tool/checker esistenti e gli orchestratori di preflight/release, senza
comandi arbitrari e con propagazione fail-closed degli exit status.

## 7. SEMANTICA DIGEST
DONE=closed | IN PROGRESS=open+PR open collegata | BLOCKED=blockedBy OR status:blocked | NEXT=open senza PR non blocked, ordine P0→P1→P2→none poi issue number | ATTENTION=check fallito OR conflitto OR status:attention | Progress=milestone closed/total; feature=sub-issues closed/total. Cache eventuale .cache/ gitignorata, non autorevole.

## 8. CONVENZIONI
Labels canoniche (.github/labels.yml): priority:P0/P1/P2, status:blocked, status:attention, type:feature/bug/task, scope:exception. VIETATE status:done/in-progress.
label-sync: action OSS pinnata SHA; sincronizza canoniche; NON elimina extra.
Dependabot: core, weekly grouped, ecosistemi solo se presenti.
Copier: `integration_mode=standalone|mcp`; default `standalone`; nessuna autodetection runtime.
Linking Issue↔PR: solo closing keyword nativa.
Issue Forms: Goal/Scope/Acceptance/Verify/Decision references.
PR template: Linked Issue/Primary Scope/Cross-scope/Justification/Verification.
Branching: 1 issue=1 branch=1 PR; da main aggiornato.

## 9. CI
Ordine: checkout→anti-rot→actionlint→zizmor→Gitleaks→paths detection→scope guard→language detection→static checks→test→build→test reporter→CI Gate.
Concurrency: PR cancel-in-progress true; main false.
Timeout: Linux static 10m, Linux test/build 20m, macOS Swift 30m, self-test 30m.
GITHUB_TOKEN default contents:read; elevazioni solo per-job.

## 10. ACCEPTANCE
ACC-01..23 = contratto eseguibile. ACC-19 verifica anche che Copier escluda i file MCP in modalità `standalone` e li includa in modalità `mcp`. acceptance/cases/ è la trascrizione eseguibile di questa SPEC, compilata SOLO da questa SPEC, commitata CONTESTUALMENTE a questo file. In caso di divergenza, SPEC-V1.md prevale.

## 11. REGOLE AGENTI
Leggi SPEC-V1.md prima di ogni modifica | non reimplementare esistente | no custom framework | tool prima della CI | test locali prima dell'integrazione | Bash set -euo pipefail ShellCheck-clean | YAML actionlint-clean | JSON jq-validabile | non conforme→STOP e segnala.

## 12. GOVERNANCE DELLA SPEC
- La SPEC è congelata. L'agente NON la modifica mai autonomamente.
- Miglioria individuata → NON implementata; scritta nel report di fase
  (cosa/perché/costo/valore/V1 o post-V1); esecuzione prosegue come da SPEC.
- Modifiche approvate solo dall'architetto (owner), in commit/PR dedicato,
  con version bump SPEC + ADR in DECISIONS.md.
- Deroghe senza nuova decisione ammesse SOLO per: errore tecnico concreto,
  incompatibilità GitHub reale, deadlock operativo, violazione single source
  of truth, alternativa plug-and-play chiaramente superiore.
  Anche in questi casi: l'agente segnala e attende istruzione.
