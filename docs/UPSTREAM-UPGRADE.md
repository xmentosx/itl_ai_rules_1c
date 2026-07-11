# Upstream release intake

Use this procedure only after upstream publishes a release tag.

1. Fetch upstream branches and tags with pruning.
2. Resolve and record the tag object and exact commit SHA.
3. Create `upgrade/<normalized-tag>` directly from that commit.
4. Run the unmodified upstream checks and record their baseline result.
5. Compare installer protocol, adapters, generated paths, OpenSpec bundle,
   `AGENTS.md`, tests, and distribution terms with the previous audited base.
6. Classify every downstream patch as `keep`, `drop`, or `rewrite`.
7. Transfer only approved bootstrap and downstream commits.
8. Run the fork gate and generate release provenance before tagging.

Do not use `upstream/main` when no release tag exists. Do not merge an earlier
ITL release branch into a new upgrade branch.

Recommended commands, with `<tag>` replaced by the published upstream tag:

```powershell
.\scripts\new-upstream-upgrade.ps1 -UpstreamTag <tag>
.\scripts\check.ps1 -Mode Full
```

After downstream adaptation and review, create the local release branch/tag:

```powershell
.\scripts\publish-fork-release.ps1 -UpstreamTag <tag> -Revision 1
```

Inspect the resulting refs, then repeat with `-Push`. Publication uses one
atomic push so the release branch and immutable tag cannot be partially sent.

If the upstream tag is moved after intake, discard the unpublished upgrade
branch and restart review from the newly verified commit. Never repair that
situation by silently changing an already published ITL tag.
