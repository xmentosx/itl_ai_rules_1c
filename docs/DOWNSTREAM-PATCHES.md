# Downstream patch ledger

Functional adapter, installer, OpenSpec, and `AGENTS.md` changes remain empty
during fork bootstrap. They are evaluated against each selected upstream tag or
full commit snapshot rather than inferred from a moving branch name.

Every downstream patch added later must have one row:

| ID | Purpose | Upstream contract | Verification | Next upgrade |
|---|---|---|---|---|
| ITL-INFRA-001 | Local fork policy and Full gate | Repository process only | `scripts/check.ps1 -Mode Full` | keep |
| ITL-INFRA-002 | Immutable tag-or-commit intake and atomic fork release tooling | Git refs, full commit IDs and release tags | `tests/ReleaseTooling.Tests.ps1` | keep |
| ITL-INSTALL-001 | Build and validate a complete installation plan before any managed write | Adapter destinations and rendered artifact bytes | `tests/LayoutAndManifest.Tests.ps1` conflict and root-boundary cases | keep |
| ITL-MANIFEST-001 | Protocol 1.1 project scope, multi-owner files, and byte-idempotent no-op updates | `.ai-rules.json` managed-entry contract | `tests/LayoutAndManifest.Tests.ps1` manifest, add/remove, idempotency cases | keep |
| ITL-LAYOUT-001 | Share Codex/Kilo general and OpenSpec skills under `.agents/skills` | Codex/Kilo repo skill discovery | inventory tests plus Kilo runtime qualification | keep |
| ITL-CODEX-001 | Stop managing global Codex prompts and require immutable updaterules sources | Codex repo skills and ITL helper ownership | fake-profile preservation tests and updaterules content check | keep |
| ITL-KILO-001 | Use `.kilo` only and migrate hash-matching legacy `.kilocode` artifacts | Kilo v7 project commands, skills, and MCP layout | clean/modified migration tests plus Kilo runtime qualification | keep |
| ITL-CONTEXT-001 | Keep always-on `AGENTS.md` within 24 KiB and route detail on demand | Root context contract and internal links | `tests/LayoutAndManifest.Tests.ps1` budget and link cases | keep |
| ITL-MCP-001 | Treat unresolved optional MCP servers as disabled and unresolved required servers as installation errors | `content/mcp-servers.json` `required` field and placeholder rendering | `tests/LayoutAndManifest.Tests.ps1` placeholder cases | keep |

Allowed values for **Next upgrade** are:

- `keep` — upstream contract is unchanged and the patch is still required;
- `drop` — upstream now provides the required behavior;
- `rewrite` — the requirement remains but the upstream contract changed.

The ledger is reviewed before every immutable ITL tag. Commit hashes alone are
not an explanation and are not sufficient ledger entries.
