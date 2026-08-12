# Downstream requirement ledger — `410951e7` / r25

The r25 candidate is rebuilt directly from upstream commit
`410951e74fd3e6b7a763cf49757935b9a34d3f31`. It accepts the corrected upstream
semantics for `&Вместо`, `&ИзменениеИКонтроль`, and `ПродолжитьВызов()` unchanged
while preserving the qualified r24 single-client ITL lifecycle contract. The
previous qualified release is `itl-main-410951e7-r24`; downstream revisions
remain globally monotonic. No earlier downstream branch is merged or rebased
onto the upstream intake.

The workflow schema-3 path ledger maps every upstream or downstream path to one
requirement below and pins upstream, baseline, and result SHA-256 values. An
unchanged `carry-forward` path remains byte-equivalent to its qualified baseline; any changed
path requires an explicit reviewed `resolved` decision.

| ID | Decision | Current treatment | Verification |
|---|---|---|---|
| ITL-INFRA-001 | `keep` | Preserve fork policy, local Full gate, exact qualification record, immutable publication tooling, and whitespace validation of the complete upstream-to-release diff. | `ReleaseTooling.Tests.ps1`, Full gate |
| ITL-INFRA-002 | `keep` | Require an immutable upstream ref/SHA and atomic release branch/tag publication. | publish `-WhatIf`, ancestry checks |
| ITL-INFRA-003 | `keep` | On pushed releases, fast-forward `origin/main` to the audited upstream snapshot in the same atomic push as the immutable release branch/tag. | `ReleaseTooling.Tests.ps1`, remote ancestry preflight |
| ITL-INSTALL-001 | `keep` | Preserve installer protocol `1.1`, complete pre-write plan, rollback-friendly ownership, and root-boundary checks. | installer/layout tests |
| ITL-INSTALL-ENTRY-001 | `rewrite` | Retain clean adapter entry files such as `CLAUDE.md` while rebuilding the update manifest, preventing a pristine first update from being mislabeled `userModified`. | Claude init/update byte-idempotence regression |
| ITL-INSTALL-REMOVE-001 | `rewrite` | Map Kilo cleanup to `.kilo` plus legacy `.kilocode` without executing the upstream orphan `else`; preserve non-empty RTK-owned `.kilocode/rules`. | full Kilo remove regression |
| ITL-INSTALL-DEVENV-001 | `rewrite` | Treat the root `.dev.env` as project-owned runtime state: never delete it during full or client-scoped removal, and normalize legacy manifest entries without changing dotenv bytes or recorded drift. | legacy full/scoped remove and metadata-backfill regressions |
| ITL-MANIFEST-001 | `rewrite` | Manifest contains exactly one active client; `other` and additive multi-client install are unsupported. | ten-client contract matrix |
| ITL-ADAPTER-002 | `rewrite` | Kimi, Qwen, Command Code, Cline, and Pi use current project-local surfaces; Cline project MCP and pinned Pi MCP extension override stale upstream assumptions. | adapter layout, merge, and runtime tests |
| ITL-LAYOUT-OLD-001 | `drop` | Do not replay the old shared Codex+Kilo layout or old `.kilocode` layout patches. Use each current native adapter. | real-path inventory tests |
| ITL-CODEX-001 | `rewrite` | Codex commands and OpenSpec skills are project-local `.agents/skills`; never write `~/.codex/prompts`. | Codex inventory and user-scope guard |
| ITL-CODEX-OPSX-001 | `rewrite` | Keep upstream `openspec-*` skills canonical and implicitly invokable; expose exactly four explicit `opsx-*` names, give Codex aliases matching `display_name` values, flatten Claude `/opsx-<stage>`, and reconstruct every client idempotently through the overlay. | all-client explicit-name inventory, Codex picker policy, old-name absence, and overlay idempotence tests |
| ITL-KILO-001 | `rewrite` | Use `.kilo` native paths, inject `USER-RULES.md` through `.kilo/kilo.json`, and block adjacent `.kilo/kilo.jsonc`. | Kilo config tests |
| ITL-ADAPTER-001 | `rewrite` | Support exactly one of the ten registered clients; preserve each native layout and OpenCode singular `agent/command`. | ten-client adapter matrix |
| ITL-CONTEXT-001 | `keep` | Preserve the compact router and on-demand detail. | context/link tests |
| ITL-MCP-002 | `keep` | Preserve delegated MCP ownership and required/optional server handling; route branch-delta source to the worktree first while keeping untouched baseline search bounded MCP-first. | delegated MCP and search-routing tests |
| ITL-OPENSPEC-001 | `rewrite` | Preserve upstream snapshot `1.2.0`; apply the project-skill/source/test-plan/fresh-check preflight and runtime Caveman response-style contract to all four native phases, including archive, without shortening artifacts, safety, checks, or reports. | native overlay, auto-phase matrix, and natural-contract tests |
| ITL-QUICKFIX-001 | `rewrite` | Keep `QUICKFIX_MAX_LINES=40`; apply upstream quick-fix/full-cycle classification exactly; keep full-cycle direct by default and select OpenSpec only for explicit or value-adding formal agreement; keep final evidence governed by effective ITL modes. | `R8Policy.Tests.ps1` and workflow overlay/docs tests |
| ITL-COMMANDS-001 | `rewrite` | Publish the explicit allowlist, suppress four generic MCP/update commands, and route the four legacy 1C commands through ITL state reconciliation. | command-surface tests |
| ITL-VERIFY-001 | `rewrite` | Upstream owns `VERIFICATION_DEPTH`/`UI_TESTING`; host ITL owns independent Vanessa/event-log modes and partial-evidence semantics. | fork policy tests and workflow mode matrix |
| ITL-ECONOMY-001 | `rewrite` | Keep upstream orchestration/model tiers with single-client validation, pinned rerender, and host-generated routine agents. | economy contract tests |
| ITL-DOCTOR-001 | `rewrite` | Restore `/doctor` as a read-only command whose ITL checks are script-owned. | read-only policy tests |
| ITL-EVOLVE-001 | `rewrite` | Restore `/evolve` with per-entry approval, `USER-RULES` precedence, protected ITL gates, and rollback ownership. | evolve policy tests |
| ITL-CAVEMAN-001 | `rewrite` | Keep `CAVEMAN=on|auto|off` with semantic default `on`; add persistent `CAVEMAN_LEVEL=lite|full|ultra` with default/invalid `full`, session-first precedence, `/caveman persist`, and expanded status while retaining session-only level commands. | CAVEMAN configuration, persistence-scope, response-style, and policy tests |
| ITL-METADATA-001 | `keep` | Preserve metadata safety, transactional form/template tools, and supported extension load paths. | `WorkflowHardening.Tests.ps1` |
| ITL-FORM-ROUTING-001 | `rewrite` | Treat structural edits of an existing `Form.xml` as specialized-tool work whenever `1c-form-edit` supports the operation; retain manual XML only for literal corrections and unsupported repairs with an explicit reason. Drop this delta when upstream adopts an equivalent operation-based rule. | `R8Policy.Tests.ps1`, workflow overlay contract |
| ITL-UPSTREAM-ANCHORS-001 | `rewrite` | Keep the compact root contract while exposing the exact upstream cross-reference anchors `Skills and Subagents`, `A.7`, `A.8`, and `A.9`. | `R8Policy.Tests.ps1`, workflow overlay tests |
| ITL-LIFECYCLE-DB-001 | `rewrite` | In projects marked by `.agent-1c/project.json`, fail direct DB and mutating web scripts with `ITL_LIFECYCLE_HELPER_REQUIRED`; outside managed projects retain upstream behavior. | `ItlLifecycleGuard.Tests.ps1` |
| ITL-RETRY-001 | `rewrite` | Keep `/update1cbase` and `/deploy-and-test` as host-helper bridges while preserving the addressable upstream `Update retry loop` contract. | `R8Policy.Tests.ps1`, bridge policy tests |
| ITL-CLAUDE-MIGRATION-001 | `rewrite` | Install Claude on-demand rules under `.claude/rules-1c`; remove clean managed legacy copies and preserve modified copies through `legacyArtifacts.preservedProject`. | installer and layout tests |
| ITL-MEMORY-001 | `keep` | Preserve the existing `Captured during work` fallback so new and upgraded projects retain the same memory behavior. | layout/policy tests |

Upstream additions retained without a downstream replacement include the
`verification-*` rules, development process, project memory, `LLM-RULES.md`,
economy/lite/CAVEMAN surfaces, template/platform discovery rules, EPF tools,
and the common platform executable resolver. `USER-RULES.md` and ITL
lifecycle/safety gates take precedence over project-local `LLM-RULES.md`;
only explicit `/evolve` may change that file, one approved entry at a time.
