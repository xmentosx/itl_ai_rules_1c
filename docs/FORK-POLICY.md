# ITL fork policy

This repository is the controlled ITL fork of
[`comol/ai_rules_1c`](https://github.com/comol/ai_rules_1c).

## Repository roles

- `upstream/main` is observed, but is never a release input by itself.
- `origin/main` mirrors upstream and is never consumed by ITL projects.
- `codex/fork-bootstrap` contains fork-process infrastructure only.
- `upgrade/<upstream-tag>` starts directly from an immutable upstream release tag.
- `release/itl-<upstream-tag>-rN` identifies the reviewed release commit.
- `itl-<upstream-tag>-rN` is the immutable annotated tag consumed by projects.

An upstream release without a tag is not eligible. A published ITL tag is never
moved, recreated, or force-pushed. Corrections are released as the next `rN`.
The active GitHub ruleset `Protect immutable ITL release tags` blocks updates
and deletion for `refs/tags/itl-*`; verify it remains active before publication.

## Upgrade rule

Each upstream release is integrated from a new upgrade branch. Downstream
commits are reviewed and transferred individually according to
`docs/DOWNSTREAM-PATCHES.md`; an earlier release branch is never merged wholesale.

Before publishing a tag, the release must pass `scripts/check.ps1 -Mode Full`,
have a clean worktree, and record both the upstream and fork commit IDs.

## Distribution authorization

The fork owner has confirmed permission to publish modifications and downstream
tags/releases. Do not add private correspondence, credentials, or personal data
to this repository. If upstream later publishes a license or changes the stated
distribution terms, re-check them before the next release.
