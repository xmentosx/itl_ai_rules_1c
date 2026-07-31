---
description: Update the managed development branch infobase through the ITL lifecycle helper
---

# /update1cbase — ITL bridge

Run the host ITL preflight/state reconciliation first. Require a managed `itldev/*` branch, restore branch context from ITL state, and synchronize `.dev.env`. Block on `master`, outside a managed branch, or when the branch infobase cannot be proven. Never use the source infobase.

Delegate the operation to `update-dev-branch-base`. After success, persist the helper-produced state/fingerprint and rollback evidence, and mark prior verification stale. Do not reproduce platform flags or run Designer directly from this command.

## Update retry loop

The host lifecycle helper owns retry handling. After every attempt it must inspect the produced log; an error in the log is a failed attempt even when the process exit code is zero. Before retrying it terminates only the exact process PID started for that attempt, never every `1cv8` process. It fixes or reports the logged cause before another attempt, restarts from load after a failed load, and stops after at most three full attempts. Preserve the helper-produced attempt, log, state, fingerprint, and rollback evidence; never reproduce Designer or `ibcmd` flags in this bridge.
