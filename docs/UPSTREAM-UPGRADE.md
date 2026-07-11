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
7. Classify every downstream patch as `keep`, `drop`, or `rewrite`.
8. Transfer only approved bootstrap and downstream commits.
9. Run the fork gate and generate release provenance before tagging.

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

After downstream adaptation and review, create the local release branch/tag:

```powershell
.\scripts\publish-fork-release.ps1 -UpstreamTag <tag> -Revision 1
```

For a commit snapshot:

```powershell
.\scripts\publish-fork-release.ps1 `
  -UpstreamCommit <40-character-sha> -UpstreamBranch main -Revision 1
```

Inspect the resulting refs, then repeat with `-Push`. Publication uses one
atomic push so the release branch and immutable tag cannot be partially sent.

If an upstream tag is moved, or a selected snapshot is no longer reachable from
its recorded branch before publication, discard the unpublished upgrade branch
and restart review. Never repair that situation by silently changing an already
published ITL tag.
