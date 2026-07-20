# Release qualification: `itl-main-a421cf44-r3`

- Upstream source: `upstream/main`
- Upstream commit: `a421cf44eb1f5859cf2a2b74884f8fbcaefc4826`
- Downstream revision: `3`
- Manifest protocol: `1.1`
- OpenSpec bundle: `1.2.0`
- Release branch: `release/itl-main-a421cf44-r3`
- Immutable annotated tag: `itl-main-a421cf44-r3`

## Required evidence

- [x] `scripts/check.ps1 -Mode Full` passes all 29 tests for the release candidate.
- [x] Fresh Codex, Kilo, and Codex+Kilo installer smoke passes.
- [x] Fresh Codex+Kilo inventory has one shared/OpenSpec skill copy under `.agents/skills` and no `.kilocode`.
- [x] Clean and user-modified manifest 1.0 migrations pass.
- [x] User-profile Codex prompts are byte-identical before and after automated tests.
- [x] Source and rendered `AGENTS.md` stay within the 24 KiB gate.
- [x] Empty `INFOBASE_PUBLISH_URL` omits optional `1c-data-mcp` from generated clients and manifest without a recommendation.
- [x] A populated URL includes `1c-data-mcp`; an unresolved required placeholder fails installation.
- [x] The Kilo command/skill layout is unchanged from the qualified `r2` downstream patch set.
- [ ] Publish preview resolves the expected commit, branch, and tag.
- [ ] The published tag passes a fresh-clone verification.

## Recorded results

- Full gate: 29 passed, 0 failed, 0 skipped.
- MCP placeholder cases: optional omitted; optional resolved; required unresolved failure.
- Managed inventory summary: Codex/Kilo ownership and migration tests passed.
- Kilo runtime surface: unchanged from `r2`; installer smoke passed in the Full gate.
- Published fork commit: pending publication.
- Fresh-clone verification: pending publication.
