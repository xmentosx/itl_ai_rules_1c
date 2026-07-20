---
description: Update the managed development branch infobase through the ITL lifecycle helper
---

# /update1cbase — ITL bridge

Run the host ITL preflight/state reconciliation first. Require a managed `itldev/*` branch, restore branch context from ITL state, and synchronize `.dev.env`. Block on `master`, outside a managed branch, or when the branch infobase cannot be proven. Never use the source infobase.

Delegate the operation to `update-dev-branch-base`. After success, persist the helper-produced state/fingerprint and rollback evidence, and mark prior verification stale. Do not reproduce platform flags or run Designer directly from this command.
