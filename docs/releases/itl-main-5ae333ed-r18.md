# Release qualification: `itl-main-5ae333ed-r18`

- Fork repository: `https://github.com/xmentosx/itl_ai_rules_1c.git`
- Upstream ref: `refs/heads/main`
- Upstream commit: `5ae333ed49dc66989e305b286acc93691bb96926`
- Downstream revision: `18`
- Previous qualified release: `itl-main-72665287-r17`
- Manifest protocol: `1.1`
- Release branch: `release/itl-main-5ae333ed-r18`
- Immutable annotated tag: `itl-main-5ae333ed-r18`

## Upstream intake

This release accepts the upstream metadata hard gate, platform-capability and
template-reuse guidance, common platform executable resolver, Claude
`.claude/rules-1c` layout, and OpenCode `toolsToPermission` post-render gate.
The upstream agents, query rules, MCP guidance, EPF tools, and resolver remain
byte-equivalent to the audited upstream wherever the path ledger says
`take-upstream`.

## Controlled differences

- The compact root `AGENTS.md` retains ITL routing and exposes the exact
  upstream `Skills and Subagents`, `A.7`, `A.8`, and `A.9` anchors.
- Structural changes to an existing `Form.xml` still use `1c-form-edit`
  whenever the operation is supported.
- In projects marked by `.agent-1c/project.json`, direct DB and mutating web
  scripts fail with `ITL_LIFECYCLE_HELPER_REQUIRED`; the host workflow remains
  responsible for the proven branch infobase, rollback, publication, and fresh
  verification. Non-managed projects keep upstream script behavior.
- `/update1cbase` and `/deploy-and-test` remain host-helper bridges and retain
  the addressable `Update retry loop` contract.
- Clean managed Claude files under `.claude/rules` migrate to
  `.claude/rules-1c`; modified legacy files are preserved and recorded in
  `legacyArtifacts.preservedProject`.
- The existing memory fallback is retained so new and upgraded projects have
  the same behavior.
- Single-client installation, delegated MCP ownership, command allowlists,
  OpenSpec aliases, and all prior ITL verification protections remain in force.

## Qualification contract

The release is publishable only after:

1. the path-level workflow verifier confirms all 51 upstream paths and the
   additional downstream safety paths on a clean linear release history;
2. targeted guard, policy, installer, layout, and migration regressions pass;
3. `scripts/check.ps1` completes successfully on the final release tree;
4. `scripts/publish-fork-release.ps1 -WhatIf` validates the exact release
   branch/tag operation.

The immutable branch and tag are published only for the Full-qualified commit.
