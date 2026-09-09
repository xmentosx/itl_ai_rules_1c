# Targeted release qualification: `itl-main-5ae333ed-r19`

- Fork repository: `https://github.com/xmentosx/itl_ai_rules_1c.git`
- Upstream ref: `refs/heads/main`
- Upstream commit: `5ae333ed49dc66989e305b286acc93691bb96926`
- Downstream revision: `19`
- Previous qualified release: `itl-main-5ae333ed-r18`
- Manifest protocol: `1.1`
- Release branch: `release/itl-main-5ae333ed-r19`
- Immutable annotated tag: `itl-main-5ae333ed-r19`

## Scope

The root `.dev.env` is project-owned runtime state. Full and client-scoped
removal preserve it by resolved root path regardless of legacy `template`,
`userModified`, or `owners` metadata. Init and update backfill
`template: true` on an existing canonical manifest entry without rewriting the
dotenv or changing its recorded hash and drift state.

## Targeted evidence

- `tests/Installer.Tests.ps1`, including exact-byte full `remove -> init`,
  client-scoped remove, legacy metadata backfill, and secret-canary log checks;
- workflow path-ledger reconstruction and verification;
- PowerShell parser and `git diff --check`;
- workflow compatibility, lock, migration, and client-replacement contracts.

Per the maintainer's explicit instruction, fork Full and workflow
Fast/Full/Release gates are not part of this targeted qualification.
