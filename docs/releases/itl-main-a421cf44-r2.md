# Release qualification: `itl-main-a421cf44-r2`

- Upstream source: `upstream/main`
- Upstream commit: `a421cf44eb1f5859cf2a2b74884f8fbcaefc4826`
- Downstream revision: `2`
- Manifest protocol: `1.1`
- OpenSpec bundle: `1.2.0`
- Release branch: `release/itl-main-a421cf44-r2`
- Immutable annotated tag: `itl-main-a421cf44-r2`

## Required evidence

- [x] `scripts/check.ps1 -Mode Full` passes from a clean worktree.
- [x] Fresh isolated smoke passes for Codex, Kilo, Codex+Kilo, Cursor, Claude Code, OpenCode, and `other`.
- [x] Fresh Codex+Kilo inventory has one copy of shared/OpenSpec skills under `.agents/skills` and no `.kilocode`.
- [x] Clean and user-modified manifest 1.0 migrations pass.
- [x] User-profile Codex prompts are byte-identical before and after all automated tests.
- [x] Source and rendered `AGENTS.md` are at most 24 KiB.
- [x] Kilo Code runtime smoke passes with `kilocode.kilo-code` 7.4.5 after `/reload`.
- [x] Kilo discovers `doctor`, `1c-metadata-manage`, and `openspec-propose` skills.
- [x] Kilo exposes `/opsx-propose`, exposes exactly one skill-backed `/doctor` entry, has no `.kilo/commands/doctor.md` duplicate, and the project has no `.kilocode`.
- [x] Publish preview resolves the expected commit, branch, and tag.
- [x] The published tag passes a fresh-clone verification.

## Recorded results

Fill this section only from executed gates. A failed or unverified item blocks publication.

- Source `AGENTS.md` bytes: 7,354
- Rendered Codex+Kilo `AGENTS.md` bytes: 7,363
- Managed inventory summary: 224 files; 23 shared skill directories (124 managed files); 4 Kilo OpenSpec commands; no `.codex/skills`, `.kilo/skills`, or `.kilocode`
- Full gate: passed 26/26 from clean commit `d4a0db927997506ac4addcb670c0467f49ceee82`
- Kilo runtime steps/result: passed on 2026-07-12 with `kilocode.kilo-code` 7.4.5; opened `build/kilo-r2-runtime`, ran `/reload`, observed one result for each required skill, four `/opsx-*` commands, and one (not duplicated) skill-backed `/doctor`
- Published fork commit: `bcb662c1eb682c1eae94cef8ad56cec0983f41d5`; annotated tag object `f53d3b9a0731eb03166a2de33c0c155e032ab4c7`
- Fresh-clone verification: passed 26/26 from `https://github.com/xmentosx/itl_ai_rules_1c.git`, detached at immutable tag `itl-main-a421cf44-r2`; resolved commit matched the release branch exactly
