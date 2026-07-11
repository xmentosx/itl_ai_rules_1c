# Downstream patch ledger

Functional adapter, installer, OpenSpec, and `AGENTS.md` changes remain empty
during fork bootstrap. They are evaluated against each selected upstream tag or
full commit snapshot rather than inferred from a moving branch name.

Every downstream patch added later must have one row:

| ID | Purpose | Upstream contract | Verification | Next upgrade |
|---|---|---|---|---|
| ITL-INFRA-001 | Local fork policy and Full gate | Repository process only | `scripts/check.ps1 -Mode Full` | keep |
| ITL-INFRA-002 | Immutable tag-or-commit intake and atomic fork release tooling | Git refs, full commit IDs and release tags | `tests/ReleaseTooling.Tests.ps1` | keep |

Allowed values for **Next upgrade** are:

- `keep` — upstream contract is unchanged and the patch is still required;
- `drop` — upstream now provides the required behavior;
- `rewrite` — the requirement remains but the upstream contract changed.

The ledger is reviewed before every immutable ITL tag. Commit hashes alone are
not an explanation and are not sufficient ledger entries.
