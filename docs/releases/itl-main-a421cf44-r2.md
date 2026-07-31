# Release qualification: `itl-main-a421cf44-r2`

- Upstream source: `upstream/main`
- Upstream commit: `a421cf44eb1f5859cf2a2b74884f8fbcaefc4826`
- Downstream revision: `2`
- Manifest protocol: `1.1`
- OpenSpec bundle: `1.2.0`
- Release branch: `release/itl-main-a421cf44-r2`
- Immutable annotated tag: `itl-main-a421cf44-r2`

## Required evidence

- [ ] `scripts/check.ps1 -Mode Full` passes from a clean worktree.
- [ ] Fresh clone smoke passes for Codex, Kilo, and Codex+Kilo.
- [ ] Fresh Codex+Kilo inventory has one copy of shared/OpenSpec skills under `.agents/skills` and no `.kilocode`.
- [ ] Clean and user-modified manifest 1.0 migrations pass.
- [ ] User-profile Codex prompts are byte-identical before and after all automated tests.
- [ ] Source and rendered `AGENTS.md` are at most 24 KiB.
- [ ] Kilo Code runtime smoke passes with `kilocode.kilo-code` 7.4.5 after `/reload`.
- [ ] Kilo discovers `doctor`, `1c-metadata-manage`, and `openspec-propose` skills.
- [ ] Kilo exposes `/opsx-propose`, exposes no general `/doctor` command duplicate, and the project has no `.kilocode`.
- [ ] Publish preview resolves the expected commit, branch, and tag.
- [ ] The published tag passes a fresh-clone verification.

## Recorded results

Fill this section only from executed gates. A failed or unverified item blocks publication.

- Source `AGENTS.md` bytes: pending
- Rendered Codex+Kilo `AGENTS.md` bytes: pending
- Managed inventory summary: pending
- Full gate: pending
- Kilo runtime steps/result: pending
- Published fork commit: pending
- Fresh-clone verification: pending
