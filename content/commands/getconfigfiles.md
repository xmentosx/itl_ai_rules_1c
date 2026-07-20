---
description: Transactionally dump selected objects from the current managed branch infobase through ITL
---

# /getconfigfiles — ITL partial-dump bridge

Run the host ITL preflight/state reconciliation. Require a managed `itldev/*` branch, a proven branch infobase, and an explicit selected-object set. Block on `master`, outside managed state, on dirty-state conflicts, or if the operation would target the source infobase.

Delegate the transactional partial dump to the ITL helper. On success update state/fingerprint, preserve rollback evidence, and mark verification stale. On failure restore the snapshot. Do not build `repoobjects.txt` or invoke platform tools independently of the helper.
