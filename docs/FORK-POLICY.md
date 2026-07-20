# ITL fork policy

This repository is the controlled ITL fork of
[`comol/ai_rules_1c`](https://github.com/comol/ai_rules_1c).

## Repository roles

- `upstream/main` is observed, but its moving branch name is never a release
  input by itself.
- `origin/main` mirrors upstream and is never consumed by ITL projects.
- `codex/fork-bootstrap` contains fork-process infrastructure only.
- `upgrade/<source-id>` starts directly from an immutable upstream tag or from
  a reviewed full 40-character commit SHA.
- `release/itl-<source-id>-rN` identifies the reviewed release commit.
- `itl-<source-id>-rN` is the immutable annotated tag consumed by projects.

An upstream tag is preferred when available. If upstream publishes only a
moving main branch, intake may designate its current tip as a stable snapshot.
The operator must pass the full SHA explicitly; the intake script verifies that
it equals the remote branch tip at that moment and records both ref and commit.
A short SHA, an unpinned branch name, or an arbitrary stale commit is not
eligible. A published ITL tag is never moved, recreated, or force-pushed.
Corrections are released as the next `rN`. The active GitHub ruleset `Protect
immutable ITL release tags` blocks updates and deletion for `refs/tags/itl-*`;
verify it remains active before publication.

## Upgrade rule

Each upstream tag or approved commit snapshot is integrated from a new upgrade
branch. Downstream
commits are reviewed and transferred individually according to
`docs/DOWNSTREAM-PATCHES.md`; an earlier release branch is never merged wholesale.

Before publishing a tag, the release must pass `scripts/check.ps1 -Mode Full`,
have a clean worktree, and record both the upstream and fork commit IDs. The
Full gate writes the ignored exact qualification record at
`build/test-results/qualification/full.json`. Release tooling may reuse only a
passed record whose commit, tree, clean state, complete test inventory, gate
scripts and JUnit hashes still match; missing, corrupt or stale records cause a
real Full run and are never a bypass for release preflight.

## Distribution authorization

The fork owner has confirmed permission to publish modifications and downstream
tags/releases. Do not add private correspondence, credentials, or personal data
to this repository. If upstream later publishes a license or changes the stated
distribution terms, re-check them before the next release.
