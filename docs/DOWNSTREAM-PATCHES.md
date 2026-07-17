# Downstream patch ledger — `b4d9875b` / r8

This release is rebuilt directly from upstream commit
`b4d9875b15c6d93f493035aee51f077126e72a21`. No previous downstream branch or
commit chain is merged or rebased onto it. Each previous requirement is
classified as `keep`, `drop`, or `rewrite` against this snapshot.

| ID | Decision | r8 treatment | Verification |
|---|---|---|---|
| ITL-INFRA-001 | `keep` | Preserve fork policy, local Full gate, exact qualification record, and immutable publication tooling. | `ReleaseTooling.Tests.ps1`, Full gate |
| ITL-INFRA-002 | `keep` | Require an immutable upstream ref/SHA and atomic release branch/tag publication. | publish `-WhatIf`, ancestry checks |
| ITL-INSTALL-001 | `keep` | Preserve installer protocol `1.1`, complete pre-write plan, rollback-friendly ownership, and root-boundary checks. | installer/layout tests |
| ITL-MANIFEST-001 | `rewrite` | Manifest contains exactly one active client; `other` and additive multi-client install are unsupported. | five-client contract matrix |
| ITL-LAYOUT-OLD-001 | `drop` | Do not replay the old shared Codex+Kilo layout or old `.kilocode` layout patches. Use each current native adapter. | real-path inventory tests |
| ITL-CODEX-001 | `rewrite` | Codex commands and OpenSpec skills are project-local `.agents/skills`; never write `~/.codex/prompts`. | Codex inventory and user-scope guard |
| ITL-KILO-001 | `rewrite` | Use `.kilo` native paths, inject `USER-RULES.md` through `.kilo/kilo.json`, and block adjacent `.kilo/kilo.jsonc`. | Kilo config tests |
| ITL-ADAPTER-001 | `rewrite` | Support exactly one of Codex, Kilo, Claude Code, Cursor, or OpenCode; preserve OpenCode singular `agent/command`. | adapter matrix |
| ITL-CONTEXT-001 | `keep` | Preserve the compact router and on-demand detail. | context/link tests |
| ITL-MCP-002 | `keep` | Preserve delegated MCP ownership and required/optional server handling. | delegated MCP tests |
| ITL-OPENSPEC-001 | `rewrite` | Add a short mechanical project-skill/source/test-plan/fresh-check preflight to explore/propose/apply for all clients. | 27-surface overlay tests |
| ITL-QUICKFIX-001 | `rewrite` | Keep `QUICKFIX_MAX_LINES=40`; quick-fix classification is mechanical and final evidence follows effective ITL modes. | policy tests and workflow matrix |
| ITL-COMMANDS-001 | `rewrite` | Publish the explicit allowlist, suppress four generic MCP/update commands, and route the four legacy 1C commands through ITL state reconciliation. | command-surface tests |
| ITL-VERIFY-001 | `rewrite` | Upstream owns `VERIFICATION_DEPTH`/`UI_TESTING`; host ITL owns independent Vanessa/event-log modes and partial-evidence semantics. | fork policy tests and workflow mode matrix |
| ITL-ECONOMY-001 | `rewrite` | Keep upstream orchestration/model tiers with single-client validation, pinned rerender, and host-generated routine agents. | economy contract tests |
| ITL-DOCTOR-001 | `rewrite` | Restore `/doctor` as a read-only command whose ITL checks are script-owned. | read-only policy tests |
| ITL-EVOLVE-001 | `rewrite` | Restore `/evolve` with per-entry approval, `USER-RULES` precedence, protected ITL gates, and rollback ownership. | evolve policy tests |
| ITL-CAVEMAN-OLD-001 | `drop` | Remove the former category override and category variables; retain the unmodified upstream command/skill semantics and blank default. | CAVEMAN policy tests |
| ITL-METADATA-001 | `keep` | Preserve metadata safety, transactional form/template tools, and supported extension load paths. | `WorkflowHardening.Tests.ps1` |

Upstream additions retained without a downstream replacement include the
`verification-*` rules, development process, project memory, `LLM-RULES.md`,
economy/lite/CAVEMAN surfaces, and current metadata tools. `USER-RULES.md` and
ITL lifecycle/safety gates take precedence over project-local `LLM-RULES.md`;
only explicit `/evolve` may change that file, one approved entry at a time.
