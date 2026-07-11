# Downstream patch ledger

This ledger is deliberately empty during fork bootstrap. Functional adapter,
installer, OpenSpec, and `AGENTS.md` changes will be designed against the next
upstream release rather than the current pre-release structure.

Every downstream patch added later must have one row:

| ID | Purpose | Upstream contract | Verification | Next upgrade |
|---|---|---|---|---|
| _none yet_ | | | | |

Allowed values for **Next upgrade** are:

- `keep` — upstream contract is unchanged and the patch is still required;
- `drop` — upstream now provides the required behavior;
- `rewrite` — the requirement remains but the upstream contract changed.

The ledger is reviewed before every immutable ITL tag. Commit hashes alone are
not an explanation and are not sufficient ledger entries.

