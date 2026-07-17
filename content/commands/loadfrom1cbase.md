---
description: Transactionally dump the current managed branch infobase through the ITL lifecycle helper
---

# /loadfrom1cbase — ITL full-dump bridge

Run the host ITL preflight/state reconciliation. Require a managed `itldev/*` branch and a proven branch infobase; block on `master`, outside managed state, on dirty-state conflicts, or if only the source infobase is available.

Delegate a transactional full dump of the current branch infobase to the ITL helper. On success update state/fingerprint, retain rollback evidence, and mark verification stale. On failure restore the helper snapshot. Do not improvise direct Designer or `ibcmd` commands here.
