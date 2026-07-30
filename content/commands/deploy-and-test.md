---
description: Run the ITL branch verification pipeline for the current managed development branch
---

# /deploy-and-test — ITL verification bridge

Run the host ITL preflight/state reconciliation. Require a managed `itldev/*` branch and its branch infobase; block on `master`, outside managed state, or when the target cannot be proven. Never deploy to the source infobase.

Delegate to `check-dev-branch` with `trigger=command`. Effective ITL modes decide whether Vanessa and event-log components run. A skipped component creates partial/skipped evidence only and never a normal fresh pass. Respect `verificationPolicy`: `block` requires full evidence before result/close; `warn` requires explicit confirmation and may report only `implemented; executable verification skipped`, never `verified` or `done`.

Failure and retry handling is inherited from `/update1cbase` (`content/commands/update1cbase.md → Update retry loop`) and remains helper-owned. Vanessa and other executable checks start only after the helper reports a clean infobase update.
