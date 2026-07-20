# Release qualification: `itl-main-b4d9875b-r10`

- Fork repository: `https://github.com/xmentosx/itl_ai_rules_1c.git`
- Upstream ref: `refs/heads/main`
- Upstream commit: `b4d9875b15c6d93f493035aee51f077126e72a21`
- Downstream revision: `10`
- Parent release: `itl-main-b4d9875b-r9`
- Manifest protocol: `1.1`
- Release branch: `release/itl-main-b4d9875b-r10`
- Immutable annotated tag: `itl-main-b4d9875b-r10`

## Hotfix scope

Full removal now maps the Kilo client to its native `.kilo` directory and its
legacy `.kilocode` cleanup boundary instead of executing the inherited orphan
`else` command. Non-empty RTK-owned `.kilocode/rules/rtk-rules.md` remains
outside controlled-fork ownership and survives removal.

Publication requires a clean Fast and Full qualification, five-client
`init -> update -> doctor` compatibility, a real full-remove regression,
publish `-WhatIf`, and fresh-clone verification. The publication script records
the exact fork commit in the annotated tag; the workflow dependency lock records
the same immutable SHA.
