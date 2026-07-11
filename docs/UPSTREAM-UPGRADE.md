# Upstream release or commit-snapshot intake

Prefer an upstream release tag. When upstream does not publish tags, a reviewed
full commit SHA from the current tip of `upstream/main` is the stable upstream
snapshot. Never use the moving branch name alone.

1. Fetch upstream branches and tags with pruning.
2. Select either a tag or the full 40-character SHA currently at the approved
   upstream branch tip.
3. Resolve and record the source ref, exact commit SHA and tree.
4. Create `upgrade/<source-id>` directly from that commit.
5. Run the unmodified upstream checks and record their baseline result.
6. Compare installer protocol, adapters, generated paths, OpenSpec bundle,
   `AGENTS.md`, tests, and distribution terms with the previous audited base.
7. Classify every functional row in `docs/DOWNSTREAM-PATCHES.md` independently as `keep`, `drop`, or `rewrite`; do not transfer a monolithic downstream diff.
8. Transfer only approved bootstrap and downstream commits.
9. Run the fork gate, runtime-client qualification, and generate a release qualification record before tagging.

Do not pass `upstream/main` as a floating release input. Commit intake requires
the exact current remote-tip SHA and rejects stale or abbreviated values. Do not
merge an earlier ITL release branch into a new upgrade branch.

Recommended commands, with `<tag>` replaced by the published upstream tag:

```powershell
.\scripts\new-upstream-upgrade.ps1 -UpstreamTag <tag>
.\scripts\check.ps1 -Mode Full
```

When no upstream tag exists, first inspect the remote tip, then pass that full
SHA explicitly:

```powershell
git ls-remote upstream refs/heads/main
.\scripts\new-upstream-upgrade.ps1 `
  -UpstreamCommit <40-character-sha> -UpstreamBranch main
.\scripts\check.ps1 -Mode Full
```

After downstream adaptation and review, preview the exact release refs without
creating them:

```powershell
.\scripts\publish-fork-release.ps1 -UpstreamTag <tag> -Revision 1 -WhatIf
```

For a commit snapshot:

```powershell
.\scripts\publish-fork-release.ps1 `
  -UpstreamCommit <40-character-sha> -UpstreamBranch main -Revision 1 -WhatIf
```

Inspect the preview, then run the same command once with `-Push` instead of
`-WhatIf`. Do not first create local refs without `-Push`: immutable duplicate
protection intentionally rejects a second creation attempt. Publication uses
one atomic push so the release branch and immutable tag cannot be partially
sent.

If an upstream tag is moved, or a selected snapshot is no longer reachable from
its recorded branch before publication, discard the unpublished upgrade branch
and restart review. Never repair that situation by silently changing an already
published ITL tag.
