# Controlled fork release: `itl-main-5f3d3f0-r20`

- Fork repository: `https://github.com/xmentosx/itl_ai_rules_1c.git`
- Upstream ref: `refs/heads/main`
- Upstream commit: `5f3d3f03b778d7de38cf2cfb18a20cf3e7ed79d8`
- Downstream revision: `20`
- Previous qualified release: `itl-main-5ae333ed-r19`
- Manifest protocol: `1.1`
- Release branch: `release/itl-main-5f3d3f0-r20`
- Immutable annotated tag: `itl-main-5f3d3f0-r20`

## Scope

This release rebuilds the controlled fork directly from upstream `5f3d3f03`.
It accepts upstream model profiles, standard verification, support protection,
Gate 3a, XDTO/UUID, BSP access-rights, UI-testing, DT and web lifecycle tooling,
and the updated subagent contracts. The ITL overlay remains a compact routed
root contract and preserves single-client installation, delegated MCP ownership,
byte-stable `.dev.env` handling, and branch-local infobase lifecycle guards.

The upstream UI installation commands delegate to the host workflow inside an
ITL-managed project and keep their original standalone behavior elsewhere.
Database and web operations keep the independent ITL ownership guard, including
the new DT dump/load and web stop/unpublish paths.

## Qualification

Release evidence is recorded by the workflow path ledger and includes:

- classification and SHA-256 verification for all 140 upstream paths;
- machine-readable root-contract coverage for every upstream root section and
  downstream hard gate;
- upstream `tools/validate-rules.ps1`;
- fork targeted tests and Full gate;
- workflow compatibility, migration, client and lifecycle regressions.
