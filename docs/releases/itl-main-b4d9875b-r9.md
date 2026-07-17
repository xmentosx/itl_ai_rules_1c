# Release qualification: `itl-main-b4d9875b-r9`

- Fork repository: `https://github.com/xmentosx/itl_ai_rules_1c.git`
- Upstream ref: `refs/heads/main`
- Upstream commit: `b4d9875b15c6d93f493035aee51f077126e72a21`
- Downstream revision: `9`
- Parent release: `itl-main-b4d9875b-r8`
- Manifest protocol: `1.1`
- Release branch: `release/itl-main-b4d9875b-r9`
- Immutable annotated tag: `itl-main-b4d9875b-r9`

## Hotfix scope

The first clean Claude Code update now preserves the installer-owned
`CLAUDE.md` entry in the manifest rebuild. It no longer adds a false
`userModified` marker or changes manifest bytes after a clean init.

Publication requires a clean Fast and Full qualification, five-client
`init -> update -> doctor` compatibility, publish `-WhatIf`, and fresh-clone
verification. The publication script records the exact fork commit in the
annotated tag; the workflow dependency lock records the same immutable SHA.
